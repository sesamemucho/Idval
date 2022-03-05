package Idval::Plugins::Command::Validate;

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
use Scalar::Util;
use English qw( -no_match_vars );

use Idval::Config;
use Idval::Logger qw(silent_q);
use Idval::FileIO;
use Idval::DoDots;
use Idval::Validate;
use Idval::Select;

my $dbg = 0;
my $filename;
my $val_cfg;

sub init
{
    return;
}

sub main
{
    my $datastore = shift;
    my $providers = shift;
    my $cfgfile = shift;
    my $status;

    my $config = Idval::Common::get_common_object('config');
    my $selects = {config_group => 'idval_settings'};

    # As a special case, allow 'demo' as a cfg file name
    #$val_cfg->{DEBUG} = 1;
    #$Idval::Validate::DEBUG = 1;
    my $vcfg = Idval::Validate->new($cfgfile eq 'demo'
                                    ? $config->i18n_get_single_value('demo_validate_cfg', $selects)
                                    : $cfgfile);
    foreach my $f (@_)
    {
        $vcfg->add_file($f);
    }

    $val_cfg = $vcfg;
    #print STDERR "validate: val_cfg is: ", Dumper($val_cfg);
    # This is required to make sure the tagname->line_number mapping is present
    $datastore->stringify();
    $filename = $datastore->source();

    #print STDERR "validate: datastore is: ", Dumper($datastore);
    foreach my $key (sort keys %{$datastore->{RECORDS}})
    {
        $status = each_item($datastore, $key);

        if ($status != 0)
        {
            last;
        }
    }

    return $datastore;
}

sub each_item
{
    my $hash = shift;
    my $key = shift;
    my $tag_record = $hash->{RECORDS}->{$key};
    my $linenumber;
    my $tagname;
    my $gripe;

    my @rectags = $tag_record->get_all_keys();
    my $lines = $tag_record->get_value('__LINES');
    #if ($key =~ m/fil03.ogg/)
    #{
    #    print STDERR "val_cfg: ", Dumper($val_cfg);
    #}
    my $varlist = $val_cfg->merge_blocks($tag_record);

    #print STDERR "For $key, got varlist, lines: ", Dumper($varlist, $lines);

    my @gripe_list;
    # We want to display in order of the line number at with the tag appears
    foreach my $gripe_key (keys %{$varlist})
    {
        foreach my $tag (@{$varlist->{$gripe_key}})
        {
            # Tags without line numbers are calculated, and shouldn't be shown
            next unless defined $lines->{$tag};
            push(@gripe_list, [$gripe_key, $lines->{$tag}, $tag]);
        }
    }
    # Now, sort on the line number
    #print STDERR "gripe_list for $key: ", Dumper(\@gripe_list);
    my @sorted_gripes = map  { $_->[0] }
                        sort { $a->[1] <=> $b->[1] }
                        map  { [$_, $$_[1]] }
                             @gripe_list;

#     #foreach my $gripe_item (@{$varlist})
    foreach my $gripe_item (@sorted_gripes)
    {
        $gripe = $$gripe_item[0];
        $linenumber = $$gripe_item[1];
        $tagname = $$gripe_item[2];
        #print STDERR "printing $filename, $linenumber, $tagname, $gripe\n";
        silent_q("[sprintf,%s:%d: error: For %s: %s,_1,_2,_3,_4]\n", $filename, $linenumber, $tagname, $gripe);
    }

# #a.c:7: error: `garf' undeclared (first use in this function)

    return 0;
}

=pod

=head1 NAME

X<validate>validate - Validates a taglist against a set of rules

=head1 SYNOPSIS

validate validate-rule-file

=head1 DESCRIPTION

B<validate> compares the stored taglist against the rules in
    F<validate-rule-file>. It displays each violation found in a form
    that indicates the line number and kind of error. In fact, the
    format is suitable for use with Emacs's 'next-error' function.

    F<validate-rule-file> is an Idval config file (See
    L<idv/"Configuration files"> for a description of config
    files). There are two items that each block in a rule file must
    have. It is possible to have extra condition expressions, to
    restrict the application of the rules, but each rule block must
    have a special conditional and a special variable assignment:

=over

=item B<< <tagname> <op> <value> >>

Where C<tagname> represents the name of a tag in the record, C<op> is
a conditional operator (see L<idv/"Configuration files"> for a
complete list of conditional operators), and C<value> is what the
value of the tag is matched against.

For greater concision, and I hope not too much greater confusion, it
is possible to specify more than one tagname in a conditional
statement. This is done by using regular expressions. In the following
examples, I will try to show some easy and straightforward
expressions, but the full power of Perl regular expressions are
available.

If all the conditional statements in a block I<succeed>, then
B<validate> considers that an error has been detected.

=item B<GRIPE>

C<GRIPE> is what B<validate> will display if it determines an error
has been found.

=back

=head1 EXAMPLES

See also the acceptance test F<30ValidateTest.t> for several examples
that are guaranteed to be correct.

=over

=item *

Say you have music files in which Jerry Garcia's name has been
misspelled as 'Jerry Gracia'. The following block will flag all
instances of this. Note that even though the conditional uses 'Jerry
Gracia', the case is not important; it could just as well have been
'jerry gracia'.

  {
     TPE1 has Jerry Gracia
     GRIPE Jerry Garcia's name was misspelled
  }

=item *

You may want to be sure that certain fields aren't blank.

  {
     TIT2|TPE1|TALB ==
     GRIPE Tag is blank
  }

This shows the use of a regular expression. Read it as:

  If TIT2 or TPE1 or TALB is blank, GRIPE that 'Tag is blank'

=item *

  {
     TYER > 2006
     TCON == Old-Time
     GRIPE = Too new for Old-Time
  }

This is a little silly, but it shows that conditionals combine with
ANDs, just like in regular configuration files. Read it as:

  if the year (TYER) is greater that 2006 AND the genre (TCON) is
  'Old-Time', GRIPE that the file is 'Too new for Old-Time'

=back

There are also (currently) three other methods available to validate
tags. These use built-in functions to perform actions that aren't
possible with the basic conditional expressions above.

=over

=item *

  {
     TYPE == MP3
     TCON fails Check_Genre_for_id3v1
     GRIPE = Bad ID3v1 genre
  }

This makes sure that all the MP3 source files have valid ID3v1 genre
tags. The first line, C<TYPE == MP3>, selects only MP3 files. This
block will not apply to FLAC, OGG, or any other kind of music
file. The second line, C<TCON fails Check_Genre_for_id3v1>, says that
the genre tag gets passed to a built-in function
Check_Genre_for_id3v1, and that this function decides that the genre
is not a valid ID3v1 genre, and so will issue a GRIPE of 'Bad ID3v1
genre'.

=item *

  {
     TIT2|TPE1|TALB fails Check_For_Existance
     GRIPE Tag does not exist
  }

This check is a little different from the previous check for these
tags not being blank, in that this block complains if any of the tags
are not found at all.

=item *

  {
     TYER|TRCK fails Is_A_Number
     GRIPE Tag is not a number
  }

Use this to make sure that any tag that should be numeric, is.

=back

=cut

1;
