package Idval::UserPlugins::Validate;

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

use Data::Dumper;
use Scalar::Util;
use English;
use Carp;

use Idval::Constants;
use Idval::FileIO;
use Idval::DoDots;
use Idval::Validate;
use Idval::Select;

our $dbg = 0;
our $filename;
our $val_cfg;

sub init
{
    *silent_q = Idval::Common::make_custom_logger({level => $SILENT,
                                                  debugmask => $DBG_ALL,
                                                  decorate => 0});

    set_pod_input();
}

sub val
{
    my $datastore = shift;
    my $providers = shift;
    my $cfgfile = shift;
    my $status;

    my $config = Idval::Common::get_common_object('config');
    my $selects = {config_group => 'idval_settings'};

    # As a special case, allow 'demo' as a cfg file name
    my $vcfg = Idval::Validate->new($cfgfile eq 'demo'
                                    ? $config->get_single_value('demo_validate_cfg', $selects) 
                                    : $cfgfile);
    foreach my $f (@_)
    {
        $vcfg->add_file($f);
    }

    $val_cfg = $vcfg;

    $datastore->stringify();
    $filename = $datastore->get_source();

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
    my $record = $hash->{RECORDS}->{$key};
    my $tagname;
    my $tagvalue;
    my $tag;
    my $cmp_result = 1;
    my $cmp_op;
    my $cmp_value;
    my $cmpfunc;
    my $type;
    my $gripe;

    my @rectags = $record->get_all_keys();
    my $lines = $record->get_value('__LINES');
    my $blocks = $val_cfg->get_blocks($record);
    foreach my $node_id (sort keys %{$blocks})
    {
        my $block = $blocks->{$node_id};
        #print "Checking:", Dumper($block);
        #return 1 if $dbg > 5;
        #$dbg++ if @rectags;
        $tagname = $block->get_select_value('TAGNAME');
        $cmp_value = $block->get_select_value('TAGVALUE');
        $cmp_op = $block->get_select_op('TAGVALUE');
        $gripe = $block->get_assignment_value('GRIPE');

        #print "Checking block for \"$tagname\" in \"", join(' ', @rectags), "\"\n";
        next unless (($tag) = grep(/^$tagname$/, @rectags));

        # Make sure $record->{$tagname} matches with $info->{TAGVALUE}->{VALUE} using $info->{TAGVALUE}->{OP}
        #print "Checking \"$tag\" (value \"", $record->get_value($tagname), "\") against \"$cmp_value\" using \"$cmp_op\"\n";
        #$cmp_op = $info->{TAGVALUE}->{OP};
        #$cmp_value = $info->{TAGVALUE}->{VALUE};
        $type = Scalar::Util::looks_like_number($cmp_value) ? 'NUM' : 'STR';
        $cmpfunc = $Idval::Select::compare_function{$cmp_op}->{FUNC}->{$type};
        #print STDERR "Comparing \"", $record->get_value($tagname), "\" \"$cmp_op\" \"$cmp_value\" resulted in ",
        #             &$cmpfunc($record->get_value($tagname), $cmp_value) ? "True\n" : "False\n";
        no strict 'refs';
        $cmp_result = &$cmpfunc($record->get_value($tagname), $cmp_value);
        use strict;
        if (!$cmp_result)
        {
            silent_q(sprintf "%s:%d: error: %s\n", $filename,
                     exists $lines->{$tagname} ? $lines->{$tagname} : "unknown tag ($tagname)",
                     $gripe);
            last;
        }
    }

    #print $cmp_result ? "GOOD" : "BAD ", " Record ", $record->get_name(), "\n";
#     if (!$cmp_result and $gripe)
#     {
#         print "\nBecause \"$gripe\"\n\n";
#     }
#     if (!$cmp_result)
#     {
#         printf "%s:%d: error: %s\n", $self->{FILENAME}, $record->get_value('__LINE'), $gripe;
#     }
#a.c:7: error: `garf' undeclared (first use in this function)

    return 0;
}

sub set_pod_input
{
    my $help_file = Idval::Common::get_common_object('help_file');

    my $name = shift;
    my $pod_input =<<EOD;

=head1 NAME

validate - Validates the tags in a local directory.

=head1 SYNOPSIS

validate validation-config-file

validation-config-file is a cascading configuration file that defines the allowable values for the tags.

=head1 OPTIONS

This command has no options.

=head1 DESCRIPTION

B<This program> will read the given input file(s) and do something
useful with the contents thereof.

=cut

EOD
    $help_file->{'cmd_val'} = $pod_input;
}

1;
