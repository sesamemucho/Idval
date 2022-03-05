package Idval::Plugins::Command::Diff;

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

use English '-no_match_vars';
use Getopt::Long;
use Pod::Usage;
use Data::Dumper;
use Carp;

use Idval::Common;
use Idval::FileIO;
use Idval::Ui;

sub init
{
    return;
}

sub main
{

    my $datastore = shift;
    my $providers = shift;
    local @ARGV = @_;
    my $outputfile = '-';
    my $config = Idval::Common::get_common_object('config');

    my $opts = Getopt::Long::Parser->new();
    my $retval = $opts->getoptions('output=s' => \$outputfile);

    my $inputfile = shift @ARGV;
    croak "Need an input file for diff\n" unless $inputfile;

    my $input_reclist = Idval::Ui::get_source_from_file($inputfile,
                                                        $config->i18n_get_single_value('config', 'data_store',
                                                                                       {'config_group' => 'idval_settings'}));

    my $out = Idval::FileIO->new($outputfile, '>') or croak "Can't open $outputfile for writing: $ERRNO\n";

    my ($input_not_ds, $input_and_ds, $ds_not_input) =
        Idval::Ui::get_rec_diffs($input_reclist, $datastore);

    my @input_recs = sort keys %{$input_reclist};
    my @ds_recs = sort keys %{$datastore};

    print STDERR "Files in input not in ds:\n", join("\n", sort keys %{$input_not_ds}), "\n\n";
    print STDERR "Files in input and in ds:\n", join("\n", sort keys %{$input_and_ds}), "\n\n";
    print STDERR "Files in ds not in input:\n", join("\n", sort keys %{$ds_not_input}), "\n\n";

    $out->print("Deleted records:\n");
    foreach my $key (sort keys %{$ds_not_input})
    {
        $out->print("\n");
        $out->print(join("\n", $datastore->get_value($key)->format_record()));
    }

    $out->print("\nAdded records:\n");
    foreach my $key (sort keys %{$input_not_ds})
    {
        $out->print("\n");
        $out->print(join("\n", $input_reclist->get_value($key)->format_record()));
    }

    $out->print("\nChanged records:\n");
    my %change_info;
    my $change_string;
    my @sub_changes;
    foreach my $key (sort keys %{$input_and_ds})
    {

        my ($rec_input_not_ds, $rec_input_and_ds, $rec_ds_not_input) =
            $datastore->get_value($key)->diff($input_reclist->get_value($key));
            #$input_reclist->get_value($key)->diff($datastore->get_value($key));

        $change_string = '';

        if (%{$rec_input_not_ds})
        {
            @sub_changes = map {"$_ = " . $input_reclist->get_value($key)->get_value($_)} sort keys %{$rec_input_not_ds};
            $change_string .= "  Added tags:\n    " . join("\n    ", @sub_changes) . "\n";
        }

        if (%{$rec_ds_not_input})
        {
            @sub_changes = map {"$_ = " . $datastore->get_value($key)->get_value($_)} sort keys %{$rec_ds_not_input};
            $change_string .= "  Deleted tags:\n    " . join("\n    ", @sub_changes) . "\n";
        }

        if (%{$rec_input_and_ds})
        {
            @sub_changes = ();
            $change_string .= "  Changed tags:\n";
            foreach my $item (sort keys %{$rec_input_and_ds})
            {
                my @change_info = @{$rec_input_and_ds->{$item}};
                $change_string .= "    $item changed from \"$change_info[0]\" to \"$change_info[1]\"\n";
            }
        }

        if ($change_string)
        {
            $change_info{$key} = $change_string;
        }
    }

    if (scalar(%change_info))
    {
        foreach my $item (sort keys %change_info)
        {
            $out->print("For record \"$item\":\n$change_info{$item}\n");
        }
    }
    else
    {
        $out->print("No changed records\n\n");
    }


    #print STDERR Dumper($reclist);
#     foreach my $key (sort keys %{$reclist})
#     {
#         $out->print("\n");
#         $out->print(join("\n", $reclist->{$key}->format_record()));
#     }

    $out->print("\n");
    $out->close();


    return $datastore;
}

=pod

=head1 NAME

X<diff>diff - Displays differences between taglist files

=head1 SYNOPSIS

diff [options] taglist-file [taglist-file2]

 Options:
    --output=<output file>         Prints difference report to F<output file>

=head1 OPTIONS

=over 4

=item B<--output>=F<output file>

Prints a report of the differences found to F<output file>, as well as to the screen.

=back

=head1 DESCRIPTION

B<diff> displays the differences between F<taglist-file> and the
    current taglist. If a second taglist file is present, then B<diff>
    reports the differences between F<taglist-file> and F<taglist-file2>.

=cut

1;
