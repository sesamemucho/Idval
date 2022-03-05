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
    set_pod_input();

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
    my $retval = $opts->getoptions('outputfile=s' => \$outputfile);

    my $inputfile = shift @ARGV;
    croak "Need an input file for diff\n" unless $inputfile;

    my $input_reclist = Idval::Ui::get_source_from_file($inputfile,
                                                        $config->get_single_value('data_store',
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

# sub prolog
# {
#     my $self = shift;
#     my $providers = shift;
#     my $options = shift;
#     my @args = @_;
#     my $out;

#     my $outputfile =  exists($options->{'output'}) ? $options->{'output'} : '-';

#     my $inputfile =  exists($options->{'input'}) ? $options->{'input'} :
#         croak "Need an input file for diff\n";

#     my $input_reclist = Idval::Ui::get_source_from_file($inputfile,
#                                                         $self->{CONFIG}->get_single_value('data_store'));

#     my $ds_reclist = Idval::Ui::get_source_from_file('',
#                                                      $self->{CONFIG}->get_single_value('data_store'));

#     $out = Idval::FileIO->new($outputfile, '>') or croak "Can't open $outputfile for writing: $ERRNO\n";

#     my ($input_not_ds, $input_and_ds, $ds_not_input) = 
#         Idval::Ui::get_rec_diffs($input_reclist, $ds_reclist);

#     my @input_recs = sort keys %{$input_reclist};
#     my @ds_recs = sort keys %{$ds_reclist};

#     #print STDERR "Files in input not in ds:\n", join("\n", sort keys %{$input_not_ds}), "\n\n";
#     #print STDERR "Files in input and in ds:\n", join("\n", sort keys %{$input_and_ds}), "\n\n";
#     #print STDERR "Files in ds not in input:\n", join("\n", sort keys %{$ds_not_input}), "\n\n";

#     $out->print("Deleted records:\n");
#     foreach my $key (sort keys %{$ds_not_input})
#     {
#         $out->print("\n");
#         $out->print(join("\n", $ds_reclist->get_value($key)->format_record()));
#     }

#     $out->print("\nAdded records:\n");
#     foreach my $key (sort keys %{$input_not_ds})
#     {
#         $out->print("\n");
#         $out->print(join("\n", $input_reclist->get_value($key)->format_record()));
#     }

#     $out->print("\nChanged records:\n");
#     my %change_info;
#     my $change_string;
#     my @sub_changes;
#     foreach my $key (sort keys %{$input_and_ds})
#     {

#         my ($rec_input_not_ds, $rec_input_and_ds, $rec_ds_not_input) = 
#             $input_reclist->get_value($key)->diff($ds_reclist->get_value($key));

#         $change_string = '';

#         if (%{$rec_input_not_ds})
#         {
#             @sub_changes = map {"$_ = " . $input_reclist->get_value($key)->get_value($_)} sort keys %{$rec_input_not_ds};
#             $change_string .= "  Added tags:\n    " . join("\n    ", @sub_changes) . "\n";
#         }

#         if (%{$rec_ds_not_input})
#         {
#             @sub_changes = map {"$_ = " . $ds_reclist->get_value($key)->get_value($_)} sort keys %{$rec_ds_not_input};
#             $change_string .= "  Deleted tags:\n    " . join("\n    ", @sub_changes) . "\n";
#         }

#         if (%{$rec_input_and_ds})
#         {
#             @sub_changes = ();
#             $change_string .= "  Changed tags:\n";
#             foreach my $item (sort keys %{$rec_input_and_ds})
#             {
#                 my @change_info = @{$rec_input_and_ds->{$item}};
#                 $change_string .= "    $item changed from \"$change_info[0]\" to \"$change_info[1]\"\n";
#             }
#         }


# #         my ($rec_input_not_ds, $rec_input_and_ds, $rec_ds_not_input) = 
# #             Idval::Ui::get_rec_diffs($input_reclist->get_value($key),
# #                                      $ds_reclist->get_value($key));
# #         #print STDERR "\nFor $key:\n";
# #         #print STDERR "records in input not in ds:\n", join("\n", sort keys %{$rec_input_not_ds}), "\n\n";
# #         #print STDERR "records in input and in ds:\n", join("\n", sort keys %{$rec_input_and_ds}), "\n\n";
# #         #print STDERR "records in ds not in input:\n", join("\n", sort keys %{$rec_ds_not_input}), "\n\n";
# #         #print STDERR "\nFor $key:\n";
# #         #print STDERR "records in input not in ds:", Dumper($rec_input_not_ds);
# #         #print STDERR "records in input and in ds:", Dumper($rec_input_and_ds);
# #         #print STDERR "records in ds not in input:", Dumper($rec_ds_not_input);

# #         $change_string = '';
# #         @sub_changes = ();
# #         foreach my $tag (sort keys %{$rec_input_not_ds})
# #         {
# #             #print STDERR "Added: <$tag>, <", $input_reclist->get_value($key)->get_value($tag), ">\n";
# #             push(@sub_changes, "$tag = " . $input_reclist->get_value($key)->get_value($tag));
# #         }

# #         if (@sub_changes)
# #         {
# #             $change_string .= "  Added tags:\n    " . join("\n    ", @sub_changes) . "\n";
# #         }

# #         @sub_changes = ();
# #         foreach my $tag (sort keys %{$rec_ds_not_input})
# #         {
# #             push(@sub_changes, "$tag = " . $ds_reclist->get_value($key)->get_value($tag));
# #         }

# #         if (@sub_changes)
# #         {
# #             $change_string .= "  Deleted tags:\n    " . join("\n    ", @sub_changes) . "\n";
# #         }

# #         @sub_changes = ();
# #         my $input_val;
# #         my $ds_val;
# #         foreach my $tag (sort keys %{$rec_input_and_ds})
# #         {
# #             $input_val = $input_reclist->get_value($key)->get_value($tag);
# #             $ds_val = $ds_reclist->get_value($key)->get_value($tag);
# #             #print STDERR "Changes: <$tag>, <$input_val>, <$ds_val>\n";
# #             if ($input_val ne $ds_val)
# #             {
# #                 #print STDERR "HEY HEY, <$input_val>, <$ds_val>\n";
# #                 push(@sub_changes, "$tag changed from \"$ds_val\" to \"$input_val\"\n");
# #             }
# #         }

# #         if (@sub_changes)
# #         {
# #             $change_string .= "  Changed tags:\n    " . join("\n    ", @sub_changes) . "\n";
# #         }

#         if ($change_string)
#         {
#             $change_info{$key} = $change_string;
#         }
#     }

#     if (scalar(%change_info))
#     {
#         foreach my $item (sort keys %change_info)
#         {
#             $out->print("For record \"$item\":\n$change_info{$item}\n");
#         }
#     }
#     else
#     {
#         $out->print("No changed records\n\n");
#     }

    
#     #print STDERR Dumper($reclist);
# #     foreach my $key (sort keys %{$reclist})
# #     {
# #         $out->print("\n");
# #         $out->print(join("\n", $reclist->{$key}->format_record()));
# #     }

#     $out->print("\n");
#     $out->close();

#     return undef;
# }

sub set_pod_input
{
    my $help_file = Idval::Common::get_common_object('help_file');

    my $name = shift;
    my $pod_input =<<"EOD";

=head1 NAME

diff - Displays the differences between two tag listing files.

=head1 SYNOPSIS

diff [options] file1 [file2]

 Options:
   -outputfile F<output_listing_file> 

=head1 OPTIONS

=over 8

=item B<-outputfile output_listing_file>

If specified, the difference report will be sent here. Otherwise, the report will be printed to the screen.

=back

=head1 DESCRIPTION

If two files are given on the command line, B<diff> will report the
differences between these two files. If only one file is given,
B<diff> will report the differences between this file and the cached
data store.

=cut

EOD
    $help_file->set_man_info('diff', $pod_input);

    return;
}

1;
