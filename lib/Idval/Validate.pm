package Idval::Validate;

# Copyright 2008 Bob Forgey <rforgey@grumpydogconsulting.com>

# This file is part of Idval.

# Idval is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# Idval is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with Idval.  If not, see <http://www.gnu.org/licenses/>.

use strict;
use warnings;
use Data::Dumper;
use English '-no_match_vars';

use Idval::Common;
use Idval::Logger qw(nchatty nverbose);
use Idval::Data::Genres;

use base qw( Idval::Config );

my $perror = '';

# Is this a valid function name for the 'passes' validation operand?
sub CheckFunction
{
    my $func = shift;

    return 1 if $func =~ m/^(Check_Genre_for_id3v1)$/;

    $perror = "Unknown validation function \"$func\"";

    return;
}

sub perror
{
    my $retval = $perror;

    $perror = '';

    return $retval;
}

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    bless($self, ref($class) || $class);
    $self->{ALLOW_KEY_REGEXPS} = 1;
    return $self;
}

# Similar to Config.pm's evaluate, but sufficiently different
sub val_evaluate
{
    my $self = shift;
    my $noderef = shift;
    my $select_list = shift;
    my $retval = 1;
    my @s_key_list;
    my $match = '';
    my $is_regexp = 0;
    my @tags_matched = ();

    nchatty("in val_evaluate: ", Dumper($noderef)) if $self->{DEBUG};
    nchatty("val_evaluate: 1 select_list: ", Dumper($select_list)) if $self->{DEBUG};
    # If the block has no selector keys itself, then all matches should succeed
    if (not (exists($noderef->{'select'}) && ref($noderef->{'select'}) eq 'HASH'))
    {
        nchatty("Block has no selector keys, returning 2\n") if $self->{DEBUG};
        return 2;
    }

    my %selectors = %{$select_list};

    return 0 unless %selectors;

    #my $tags_to_ignore = $select_list->get_calculated_keys_re();
    my $tags_to_ignore = eval {$select_list->get_calculated_keys_re(); };
    if ($@)
    {
        confess $@;
    }

  KEY_MATCH: foreach my $block_key (keys %{$noderef->{'select'}})
    {
        if (exists ($self->{DEF_VARS}->{$block_key}))
        {
            no strict 'refs';
            my $subr = $self->{DEF_VARS}->{$block_key};
            $selectors{$block_key} = &$subr(\%selectors);
            nchatty("Using ", $selectors{$block_key}, " for \"$block_key\"\n");
            use strict;
        }

        if ($block_key eq '%FILE_TIME%')
        {
            $selectors{$block_key} = Idval::FileIO::idv_get_mtime($selectors{FILE});
        }

        my $bstor = $noderef->{'select'}->{$block_key}; # Naming convenience

        nverbose("val_evaluate: 2 select_list: ", Dumper(\%selectors)) if $self->{DEBUG};

        @s_key_list = $self->{ALLOW_KEY_REGEXPS} ? grep(/^$block_key$/, keys %selectors) :
            ($block_key);
        $is_regexp = $block_key =~ m/\W/;

        nverbose("Checking block selector \"$block_key\" (is_regexp = \"$is_regexp\")\n") if $self->{DEBUG};

        my $key_list_loop_result = 0;

        foreach my $s_key (@s_key_list)
        {
            nchatty("Checking block selector key \"$s_key\"\n") if $self->{DEBUG};
            if (!exists($selectors{$s_key}))
            {
                # The select list has nothing to match a required selector, so this must fail
                nchatty("Select list has nothing to match block selector key \"$s_key\", so return 0.\n") if $self->{DEBUG};
                return 0;
            }

            if ($is_regexp && ($s_key =~ m/$tags_to_ignore/))
            {
                nchatty("Block selector key \"$s_key\" is a tag to ignore.\n") if $self->{DEBUG};
                next;
            }

            # Make sure arg_value is a list reference
            my $arg_value_list = ref $selectors{$s_key} eq 'ARRAY' ? $selectors{$s_key} :
                [$selectors{$s_key}];

            my $block_op = $bstor->{'op'};
            my $block_value = $bstor->{'value'};
            my $block_cmp_func = Idval::Select::get_compare_function($block_op, 'STR');
            my $cmp_result = 0;

            # For any key, the passed_in selector may have a list of values that it can offer up to be matched.
            # A successful match for any of these values constitutes a successful match for the block selector.
            foreach my $value (@{$arg_value_list})
            {
                nverbose("Comparing \"$s_key\" => \"$value\" \"$block_op\" \"$block_value\" resulted in ",
                         &$block_cmp_func($value, $block_value) ? "True\n" : "False\n") if $self->{DEBUG};

                $cmp_result ||= &$block_cmp_func($value, $block_value);
                last if $cmp_result;
            }

            # Regexp matches are ORed together. For example, if a
            # block key is 'TALB|TPE1', then this loop should return
            # TRUE if either TALB or TPE1 gets a match.
            # Also note that, if the block key is not a regexp, this
            # loop will execute exactly once.

            $key_list_loop_result ||= $cmp_result;

            if ($cmp_result)
            {
                push(@tags_matched, $s_key);
            }

            nchatty("accumulated retval is now \"$retval\"\n") if $self->{DEBUG};
        }

        $retval &&= $key_list_loop_result;
    }

    nchatty("val_evaluate returning \"$retval\"\n") if $self->{DEBUG};
    return ($retval, \@tags_matched);
}

# The only variable we care about is the GRIPE
# Use 'select' key to find out which tags matched, and so get the right line number
sub get_gripes
{
    my $self = shift;
    my $selects = shift;
    my $tree = $self->{TREE};
    my @gripelist;

    nchatty("Start of _get_gripes, selects: ", Dumper($selects)) if $self->{DEBUG};

    my $visitor = sub {
        my $self = shift;
        my $noderef = shift;

        my $gripe = 'no gripe found?';
        my @match_tags = ();

        nchatty("get_gripes: noderef is: ", Dumper($noderef)) if $self->{DEBUG};
        my ($retval, $matches) = $self->val_evaluate($noderef, $selects);
        return 0 if ($retval == 0);

        nchatty("get_gripes: val_evaluate returned nonzero\n") if $self->{DEBUG};

        # There might not be a GRIPE at this node (for instance, a top-level 'group')
        if(exists $noderef->{GRIPE})
        {
            $gripe = $noderef->{GRIPE};
            push(@gripelist, [$gripe, $matches]) if @{$matches};
        }

        return 1;
    };

    $self->visit([$tree], 'top', 0, $visitor);

    # Translate tag names to line numbers
    my $gripe;
    my $linenum;
    # The $selects argument for this call had better be a tag record...
    my $lines = $selects->get_value('__LINES');
    my @retlist;
    foreach my $gripe_item (@gripelist)
    {
        $gripe = $$gripe_item[0];
        # Just flag the first bad tag
        foreach my $bad_tag (@{$$gripe_item[1]})
        {
            # If we can't find the tag (maybe it's a regexp), just return the line
            # number for the start of the tag record (the FILE line).
            $linenum = exists $lines->{$bad_tag} ? $lines->{$bad_tag} : $lines->{FILE};

            push(@retlist, [$gripe, $linenum, $bad_tag]);
            #print "Got gripe \"$gripe\" for tag \"$bad_tag\" at line number \"$linenum\"\n";
        }
    }

    nchatty("Result of merge blocks - VARS: ", Dumper(\@retlist)) if $self->{DEBUG};

    return \@retlist;
}

package Idval::ValidateFuncs;

use strict;
use Data::Dumper;

#use Idval::Logger(nfatal);

sub Check_Genre_for_id3v1
{
    my $selectors = shift;
    my $tagname = shift;
    my $tagvalue = lc($selectors->{$tagname});

    return Idval::Data::Genres::isNameValid($tagvalue);
}

sub Check_For_Existance
{
    #print "Args are: ", Dumper(@_);
    #confess "Bye";
    my $selectors = shift;
    my $tagname = shift;
    my $retval = exists $selectors->{$tagname};
    return $retval;
}

=head1 VALIDATE

=head2 NAME

Validate - Support for tag validation.

=head2 SYNOPSIS

Allows callers to validate a tag record according to a validation configuration file.

=head2 DESCRIPTION

sd
ad
asdf

=cut


1;
