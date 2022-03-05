package Idval::Plugins::Command::About;

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
use Getopt::Long;

use Idval::Common;
use Idval::Logger qw(silent_q);
use Idval::TypeMap;

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

    my $verbose = 0;
    my $show_config = 0;
    my $show_xml = 0;
    my $filters = 0;
    my $attributes = [];

    my $result = GetOptions(
        'verbose' => \$verbose,
        'config'  => \$show_config,
        'xml'     => \$show_xml,
        'filters' => \$filters,
        );

    my $typemap = Idval::TypeMap->new($providers);

    my %converters_by_type;
    my %writers_by_type;
    my %readers_by_type;
    my %providers_by_name;
    my %provider_paths;

    my $provider;
    my @msgs;

    my $help_file = Idval::Common::get_common_object('help_file');

    if ($filters)
    {
        $attributes = ['filter'];
    }

    if (@ARGV)
    {
        my $name = $ARGV[0];
        my $info_ref = $help_file->detailed_info_ref($name);

        if (defined($info_ref))
        {
            foreach my $pkg (keys %{$info_ref})
            {
                print "Information for \"${pkg}::${name}\":\n";
                print $info_ref->{$pkg};
                print "\n";
            }
        }
        else
        {
            print "No information available for \"$name\"\n";
        }
    }
    elsif ($show_config)
    {
        my $config = Idval::Common::get_common_object('config');
        my $vars = $config->merge_blocks({'config_group' => 'idval_settings'});

        print "Overall configuration values:\n";
        foreach my $key (sort keys %{$vars})
        {
            printf "%-20s:%s\n", $key, $vars->{$key};
        }
    }
    elsif ($show_xml)
    {
        my $config = Idval::Common::get_common_object('config');
        print $config->{PRETTY};
    }
    else
    {
        # Find converters
        foreach my $item ($providers->_get_providers({types => ['converts'], attributes => $attributes}))
        {
            print STDERR ("null converter?\n"), next unless defined($item);
            #print STDERR "converter: item is: ", Dumper($item);
            foreach my $endpoint ($item->get_endpoint())
            {
                my ($from, $to) = split(':', $endpoint);
                $converters_by_type{$from}->{$to} = $item;
            }
            $providers_by_name{$item->{NAME}}{'PROV'} = $item;
            $providers_by_name{$item->{NAME}}{'TYPE'} = 'Converter';
        }

        # Find readers
        foreach my $item ($providers->_get_providers({types => ['reads_tags'], attributes => $attributes}))
        {
            print STDERR ("null reader?\n"), next unless defined($item);
            $providers_by_name{$item->{NAME}}{'PROV'} = $item;
            $providers_by_name{$item->{NAME}}{'TYPE'} = 'Reader';
            foreach my $type ($item->get_source())
            {
                $readers_by_type{$type} = $item;
            }
        }

        # Find writer
        foreach my $item ($providers->_get_providers({types => ['writes_tags'], attributes => $attributes}))
        {
            print STDERR ("null writer?\n"), next unless defined($item);
            $providers_by_name{$item->{NAME}}{'PROV'} = $item;
            $providers_by_name{$item->{NAME}}{'TYPE'} = 'Writer';
            foreach my $type ($item->get_source())
            {
                $writers_by_type{$type} = $item;
            }
        }

        @msgs = ();
        push(@msgs, "Converts:");
        foreach my $converter_from_type (sort keys %converters_by_type)
        {
            foreach my $converter_to_type (sort keys %{$converters_by_type{$converter_from_type}})
            {
                $provider = $converters_by_type{$converter_from_type}->{$converter_to_type};
                $provider_paths{$provider->{NAME}} = $provider->query('path');
                my $infoline = "\tConverts from: $converter_from_type to $converter_to_type using " .
                    $provider->{NAME};
                $infoline .= $provider->query('is_ok') ? "" : "   (NOT ACTIVE)";
                push(@msgs, $infoline);
            }
        }
        silent_q(join("\n", @msgs), "\n");

        silent_q("Reads:\n");
        foreach my $reader_type (sort keys %readers_by_type)
        {
            $provider = $readers_by_type{$reader_type};
            $provider_paths{$provider->{NAME}} = $provider->query('path');
            silent_q("\tReads tags from: [_1] using [_2]\n", $reader_type, $provider->{NAME});
        }

        silent_q("Writes:\n");
        foreach my $writer_type (sort keys %writers_by_type)
        {
            $provider = $writers_by_type{$writer_type};
            $provider_paths{$provider->{NAME}} = $provider->query('path');
            silent_q("\tWrites tags to: [_1] using [_2]\n", $writer_type, $provider->{NAME});
        }

        silent_q("Types:\n");
        #print STDERR "TypeMap: ", Dumper($typemap);
        foreach my $filetype ($typemap->get_all_filetypes()) {
            silent_q("\tType [_1] files have extensions: [_2]\n", $filetype,
                     join(', ', map {lc $_} $typemap->get_exts_from_filetype($filetype)));
        }
        silent_q("\n");
        foreach my $class ($typemap->get_all_classes()) {
            silent_q("\tClass [_1] comprises types: [_2]\n", $class,
                     join(', ', $typemap->get_filetypes_from_class($class)));
        }

        #if ((exists $options->{'all'}) and $options->{'all'})
        {
            silent_q("\nProvider paths:\n");
            foreach my $provider (sort keys %provider_paths)
            {
                next if $provider =~ m{/}; # This indicates a 'smooshed' combined converter,
                # whose individual components will be displayed
                # separately.
                silent_q("\tProvider [_1] uses [_2]\n", $provider, $provider_paths{$provider});
            }
        }

        #if ((exists $options->{'all'}) and $options->{'all'})
        {
            # Only display to the level of provider name and provider type.
            # It is assumed that, for different endpoints, a given provider
            # has the same characteristics

            silent_q("\nProvider info:\n");
            my %provider_status_info;
            foreach my $pinfo ($providers->direct_get_providers('converts', 'reads_tags', 'writes_tags'))
            {
                my $name = $pinfo->{'name'};
                my $type = $pinfo->{'type'};

                $provider_status_info{$name}->{$type}->{CNV} = $pinfo->{converter};

            }

            foreach my $name (sort keys %provider_status_info)
            {
                foreach my $type (sort keys %{$provider_status_info{$name}})
                {
                    my $cnv = $provider_status_info{$name}->{$type}->{CNV};

                    my $status = $cnv->query('status');
                    my $infoline = sprintf("\tProvider %-15s status for %-15s is: %s",
                                           $name, $type, $status);
                    if ($type eq 'converts' && $status eq 'ok')
                    {
                        $infoline .= $verbose ? '    attributes: ' . $cnv->query('attributes') : '';
                    }
                    $infoline .= "\n";
                    silent_q($infoline);
                }
            }
#            foreach my $pinfo ($providers->direct_get_providers('converts', 'reads_tags', 'writes_tags'))
#             {
#                 my $cnv = $pinfo->{converter};
#                 my $status = $cnv->query('status');
#                 my $infoline = sprintf("\tProvider %-15s status for %-15s is: %s",
#                                        $pinfo->{'name'}, $pinfo->{'type'}, $status);
#                 if ($pinfo->{type} eq 'converts' && $status eq 'ok')
#                 {
#                     $infoline .= $verbose ? '    attributes: ' . $cnv->query('attributes') : '';
#                 }
#                 $infoline .= "\n";
#                 silent_q($infoline);
#             }
        }

    }
    return $datastore;
}

sub set_pod_input
{
    my $help_file = Idval::Common::get_common_object('help_file');

    my $pod_input =<<"EOD";

=head1 NAME

about - Using GetOpt::Long and Pod::Usage blah blah foo booaljasdf

=head1 SYNOPSIS

about [options] [file ...]

 Options:
   -help            brief help message
   -man             full documentation

=head1 OPTIONS

=over 8

=item B<-help>

Print a brief help message and exits.

=item B<-man>

Prints the manual page and exits.

=back

=head1 DESCRIPTION

B<About> reports on interesting things in idv.

=cut

EOD
    $help_file->set_man_info('about', $pod_input);

    return;
}

1;
