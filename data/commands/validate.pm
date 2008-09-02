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
use strict;
use warnings;

use Data::Dumper;
use Scalar::Util;
use English qw( -no_match_vars );
use Carp;

use Idval::Config;
use Idval::Constants;
use Idval::FileIO;
use Idval::DoDots;
use Idval::Validate;
use Idval::Select;

my $dbg = 0;
my $filename;
my $val_cfg;
my $silent_q;

sub init
{
    *silent_q = Idval::Common::make_custom_logger({level => $SILENT,
                                                  debugmask => $DBG_ALL,
                                                  decorate => 0});

    set_pod_input();

    return;
}

sub validate
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
    #$Idval::Config::DEBUG=1;  # XXX
    #$val_cfg->{DEBUG} = 1;    # XXX

    $datastore->stringify();
    $filename = $datastore->get_source();

    #print "datastore is: ", Dumper($datastore);
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
    #print "val_cfg: ", Dumper($val_cfg);
    my $varlist = $val_cfg->merge_blocks($tag_record);

    #print "For $key, got varlist: ", Dumper($varlist);

    foreach my $gripe_item (@{$varlist})
    {
        $gripe = $$gripe_item[0];
        $linenumber = $$gripe_item[1];
        $tagname = $$gripe_item[2];
        silent_q(sprintf "%s:%d: error: For %s, %s\n", $filename, $linenumber, $tagname, $gripe);
    }

#a.c:7: error: `garf' undeclared (first use in this function)

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
    $help_file->man_info('validate', $pod_input);

    return;
}

1;
