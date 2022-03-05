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
    set_pod_input();

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
                                    ? $config->get_single_value('demo_validate_cfg', $selects)
                                    : $cfgfile);
    foreach my $f (@_)
    {
        $vcfg->add_file($f);
    }

    $val_cfg = $vcfg;
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
#     if ($key eq '/home/bob/Projects/src/idv/t/accept/../accept_data/ValidateTest/t/d1/oggs/fil03.ogg')
#     {
#         print STDERR "val_cfg: ", Dumper($val_cfg);
#     }
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
        silent_q("[sprintf,%s:%d: error: For %s, %s,_1,_2,_3,_4]\n", $filename, $linenumber, $tagname, $gripe);
    }

# #a.c:7: error: `garf' undeclared (first use in this function)

    return 0;
}

sub set_pod_input
{
    my $help_file = Idval::Common::get_common_object('help_file');

    my $name = shift;
    my $pod_input =<<"EOD";

=head1 NAME

validate - Validates the tags in a local directory.

=head1 SYNOPSIS

validate validation-config-file

validation-config-file is a cascading configuration file that defines the allowable values for the tags.

=head1 OPTIONS
X<options>
This command has no options.

=head1 DESCRIPTION

X<desc>
B<This program> will read the given input file(s) and do something
useful with the contents thereof.

=cut

EOD
    $help_file->set_man_info('validate', $pod_input);

    return;
}

1;
