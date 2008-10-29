package Idval::Interp;

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
use Term::ReadLine;
use Getopt::Long qw(:config pass_through permute);

use Idval;
use Idval::Common;
use Idval::Constants;

sub new
{
    my $class = shift;
    my $self = {};
    bless($self, ref($class) || $class);
    $self->_init(@_);
    return $self;
}

sub _init
{
    my $self = shift;

    # Get our args
    my %options;
    my $result = GetOptions(\%options, "input=s");

    my $idval = Idval->new();
    $self->{IDVAL} = $idval;

    $self->{LOG} = Idval::Common::get_logger();
    $self->{ARGS} = $idval->{REMAINING_ARGS};
    $self->{OPTIONS} = \%options;
}

# Here we enter the command loop. If there are any arguments left in @ARGV,
# this is taken as a command (followed by an implicit 'exit' command).
sub cmd_loop
{
    my $self = shift;

    my @args = @{$self->{ARGS}};
    my $input_datafile = $self->{OPTIONS}->{'input'};
    my $datastore = $self->{IDVAL}->datastore();
    my $providers = $self->{IDVAL}->providers();

    if (@args)
    {
        my $cmd = shift @args;
        my $rtn = 'Idval::Scripts::' . $cmd;
        no strict 'refs';
        if ($cmd ne 'gettags')
        {
            my $read_rtn = 'Idval::Scripts::read';
            $self->{DATASTORE} = &$read_rtn($datastore,
                                            $providers,
                                            $input_datafile);
        }

        $self->{DATASTORE} = &$rtn($datastore,
                                   $providers,
                                   @args);

        if ($datastore and $cmd eq 'gettags')
        {
            my $store_rtn = 'Idval::Scripts::store';
            no strict 'refs';
            if ($self->{OPTIONS}->{'store'})
            {
                $self->{DATASTORE} = &$store_rtn($datastore,
                                                 $providers,
                                                 '');
            }
            if ($self->{OPTIONS}->{'output'})
            {
                $self->{DATASTORE} = &$store_rtn($datastore,
                                                 $providers,
                                                 $self->{OPTIONS}->{'output'});
            }

        }

        use strict;
    }
    else
    {
        my $term = new Term::ReadLine 'IDVal';
        my $prompt = "idv: ";
        my $OUT = $term->OUT || \*STDOUT;
        my $line;
        my @line_args;
        my $temp_ds;
        my $error_occurred;

        while (defined ($line = $term->readline($prompt)))
        {
            chomp $line;

            last if $line =~ /^\s*(q|quit|exit|bye)\s*$/i;
            next if $line =~ /^\s*$/;

            @line_args = @{Idval::Common::split_line($line)};

            my $cmd_name = shift @line_args;
            $self->{LOG}->chatty($DBG_PROVIDERS, "command name: \"$cmd_name\", line args: ", join(" ", @line_args), "\n");
            my $rtn = 'Idval::Scripts::' . $cmd_name;
            no strict 'refs';
            eval { $temp_ds = &$rtn($datastore, $providers, @line_args); };
            use strict;
            #print STDERR "Interp: return is: ", Dumper($temp_ds);
            $error_occurred = 0;
            if ($@)
            {
                my $status = $!;
                my $reason = $@;
                if ($reason =~ /No script file found for command \"([^""]+)\"/)
                {
                    my $bogus = $1;
                    print "Got unrecognized command \"$bogus\", with args ", join(",", @line_args), "\n";
                    print "$@\n";
                    $error_occurred = 1;
                }
                else
                {
                    print STDERR "Yipes\n";
                    croak "Error in \"$cmd_name\": \"$status\", \"$reason\"\n";
                }
            }

            next if $error_occurred;

            $term->addhistory($line) if $line =~ /\S/;
            $self->{DATASTORE} = $temp_ds if $temp_ds;
            $datastore = $temp_ds;
        }
    }

    return;
}

# Note:
# main::(-e:1):   0
#   DB<1> $a = sub{my $x=shift; print "Hello \"$x\"\n";}

#   DB<2> &$a(44)
# Hello "44"

#   DB<3> *barf{CODE} = $a
# Can't modify glob elem in scalar assignment at (eval 7)[/usr/lib/perl5/5.8/perl5db.pl:628] line 2, at EOF

#   DB<4> *barf = *a

#   DB<5> barf(33)
# Undefined subroutine &main::a called at (eval 9)[/usr/lib/perl5/5.8/perl5db.pl:628] line 2.

#   DB<6> *barf = $a

#   DB<7> barf(33)
# Hello "33"


1;
