package Idval::UserPlugins::Help;

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

use Carp;
use Data::Dumper;
use Getopt::Long;
use Pod::Usage;
use Pod::Select;
use Text::Abbrev;

use Idval::Constants;

sub init
{
    *silent_q = Idval::Common::make_custom_logger({level => $SILENT,
                                                  debugmask => $DBG_PROCESS,
                                                  decorate => 0});

    set_pod_input();

    return;
}

sub help
{
    my $datastore = shift;
    my $providers = shift;
    local @ARGV = @_;

    my $verbose = 0;
    my $result = GetOptions("verbose" => \$verbose);

    my $typemap = Idval::TypeMap->new($providers);
    my $cmd;
    my $name = 'help';
    my $help_file = Idval::Common::get_common_object('help_file');

    my @cmd_list = $providers->find_all_commands();
    my $cmd_abbrev = abbrev map {lc $_} @cmd_list;
    my $cmd_name = $name;

    if (@ARGV)
    {
        $name = lc (shift @ARGV);
        
        croak "Unrecognized command name \"$name\"\n" unless exists($cmd_abbrev->{$name});
        $cmd_name = $cmd_abbrev->{$name};
        croak "No help information for command name \"$name\"\n" unless exists($help_file->{$cmd_name});
        $cmd = $providers->find_command($cmd_name);
    
        if ($verbose)
        {
            silent_q(get_full_description($cmd_name));
        }
        else
        {
            silent_q(get_synopsis($cmd_name));
            silent_q("\nUse \"help -v $cmd_name\" for more information.\n");
        }
    }
    else
    {
        # Just a bare 'help' command => print help for the main program
        silent_q(get_full_description('main'));
    }

    if ($cmd_name eq 'help')
    {
 
       silent_q("\nAvailable commands:\n");
       my @cmd_list = $providers->find_all_commands();
       foreach my $cmd_name (@cmd_list) {
           my $gsd = get_short_description($cmd_name);
           silent_q("  ", get_short_description($cmd_name), "\n");
       }
    }

    return 0;
}

sub _call_pod2usage
{
    my $name = shift;
    my @sections = @_;

    my $usage = '';

    my $help_file = Idval::Common::get_common_object('help_file');

    return "$name: no information available" unless exists $help_file->{$name};

    my $input = $help_file->{$name};
    open(my $INPUT, '<', \$input) || die "Can't open in-core filehandle for pod_input: $!\n";
    open(my $FILE, '>', \$usage) || die "Can't open in-core filehandle: $!\n";
    my $parser = new Pod::Text();
    $parser->select(@sections);
    $parser->parse_from_filehandle($INPUT, $FILE);
    close $FILE;
    close $INPUT;

    return $usage;
}

sub get_short_description
{
    my $name = shift;
    my $usage = _call_pod2usage($name, "NAME");

    # Now trim it
    $usage =~ s/Name\s*//si;
    $usage =~ s/\n\n*/\n/gs;
    $usage =~ s/\n*$//;
    return $usage;
}

sub get_full_description
{
    my $name = shift;

    my $usage = _call_pod2usage($name, '');

    return $usage;
}

sub get_synopsis
{
    my $name = shift;

    my $usage = _call_pod2usage($name, 'SYNOPSIS', 'OPTIONS');

    return $usage;
}

sub set_pod_input
{
    my $help_file = Idval::Common::get_common_object('help_file');

    my $pod_input =<<"EOD";

=head1 NAME

help - Using GetOpt::Long and Pod::Usage blah blah foo booaljasdf

=head1 SYNOPSIS

sample [options] [file ...]

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

B<This program> will read the given input file(s) and do something
useful with the contents thereof.

=cut

EOD
    $help_file->{'help'} = $pod_input;

    return;
}

1;
