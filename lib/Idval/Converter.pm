package Idval::Converter;

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
#use File::Temp qw/ tmpnam /;
use File::Temp qw/ :POSIX /;

use Idval::Logger qw(idv_dbg fatal);
use Idval::Common;
use base qw(Idval::Provider);

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    bless($self, ref($class) || $class);
    return $self;
}

package Idval::Converter::Smoosh;
use strict;
use warnings;
use Data::Dumper;
use Memoize;
use List::Util qw(first);

use Idval::Logger qw(verbose chatty idv_dbg fatal);
use Idval::Common;
use base qw(Idval::Converter);

memoize('get_typemap');

sub new
{
    my $class = shift;
    my $from = shift;
    my $to = shift;
    my @cnv_list = @_;
    fatal("No converters in smoosh?") unless @_ and defined($_[0]);
    my $name = join('/', map{$_->query('name')} @cnv_list);
    my $config = $cnv_list[0]->{CONFIG}; # They all have the same CONFIG object.
    my $self = $class->SUPER::new($config, $name);
    bless($self, ref($class) || $class);
    $self->init($from, $to, @cnv_list);
    return $self;
}

sub init
{
    my $self = shift;
    my $from = shift;
    my $to = shift;
    my @converters = @_;
    
    if (ref $converters[0] eq 'Idval::Converter::Smoosh')
    {
        # We are smooshing a filter or filters into a Smoosh
        my $smoosh = $converters[0];
        my @filters = @converters[1..$#converters];
        my @current_converters = $smoosh->get_converters();
        my @new_converters = ();
        my $found_a_place = 0;
        my %filter_hash;

        # Validate filters
        my $number_of_filters_to_add = scalar(@filters);
        chatty("Smooshing [quant,_1,filter,filters] into a converter\n", scalar(@filters));
        foreach my $filter (@filters)
        {
            if ($filter->get_source() ne $filter->get_destination())
            {
                fatal("Can only smoosh a filter into an existing Smoosh, trying [_1]\n", $filter->query('name'));
            }

            $filter_hash{$filter} = $filter;
        }

        # Where can we put them?
        $found_a_place = 0;

        chatty("current_converters 1: [_1]\n", join(",", map { $_->query('name') } @current_converters));
       # Should any go at the beginning?
        my $first_cnv = $current_converters[0];
        foreach my $key (keys %filter_hash)
        {
            my $filter = $filter_hash{$key}; # Can't use objects as keys, really
            if ($first_cnv->get_source() eq $filter->get_source())
            {
                # If any _do_ go at the start, then (since the input
                # and output of a filter are of the same type), any
                # others will either go at the end of the (new) first
                # converter, or somewhere after that.
                chatty("Adding filter [_1] to beginning of converter list\n", $filter->query('name'));
                unshift(@current_converters, $filter);
                $found_a_place++;
                delete $filter_hash{$filter};
                last;
            }
        }

        # Should any go after the first one?

        chatty("current_converters 2: [_1]\n", join(",", map { $_->query('name') } @current_converters));
        my $current_converter;
        my @delete_me;
        while( my $nconv = shift @current_converters)
        {
            $current_converter = $nconv;
            push(@new_converters, $current_converter);
            chatty("pushing nconv [_1] onto new_converters ([_2])\n", $nconv->query('name'),
                   join(",", map { $_->query('name') } @new_converters));
            foreach my $key (keys %filter_hash)
            {
                my $filter = $filter_hash{$key}; # Can't use objects as keys, really
                if ($current_converter->get_destination() eq $filter->get_destination())
                {
                    chatty("Adding filter [_1] after [_2]\n", $filter->query('name'), $current_converter->query('name'));
                    $found_a_place++;
                    push(@new_converters, $filter);
                    chatty("pushing filter [_1] onto new_converters ([_2])\n", $filter->query('name'),
                           join(",", map { $_->query('name') } @new_converters));
                    push(@delete_me, $key); # Can't modify %filter_hash inside the loop
                    $current_converter = $filter;
                }
            }

            foreach my $filter (@delete_me)
            {
                chatty("Deleting filter $filter\n");
                delete($filter_hash{$filter});
            }

            #push(@new_converters, $nconv);
        }

        if ($found_a_place != $number_of_filters_to_add)
        {
            fatal("Needed to place [quant,_1,filter,filters] for converter, but only placed [_2]",
                  $number_of_filters_to_add,
                  $found_a_place);
        }

        @converters = (@new_converters);
    }

    chatty("converters 1: [_1]\n", join(",", map { $_->query('name') } @converters));
    $self->{CONVERTERS} = [@converters];
    $self->{FIRSTCONVERTER} = $converters[0];
    $self->{LASTCONVERTER} = $converters[-1];

    chatty("Smooshing: [_1]\n", join(" -> ", map { $_->query('name') } @{$self->{CONVERTERS}}));
    $self->{TO} = $to;
    $self->add_endpoint_pair($from, $to);
    my $name = join('/', map{$_->query('name')} @{$self->{CONVERTERS}});
    $self->{NAME} = $name;
    $self->set_param('name', $self->{NAME});
    $self->set_param('attributes', $self->{LASTCONVERTER}->query('attributes'));

    my $is_ok = 1;
    map { $is_ok &&= $_->query('is_ok') } @{$self->{CONVERTERS}};

    $self->set_param('is_ok', $is_ok);

    return;
}

sub convert
{
    my $self = shift;
    my $rec = shift;
    my $dest = shift;

    my $src = $rec->get_name();

    return 0 if !$self->query('is_ok');

    my $from_file = $src;
    my $first_time_through = 1;
    my $to_type;
    my $to_file;
    my $ext;
    my @temporary_files;
    my $retval;
    # Make a copy of the input record so we can fool with it
    my $tag_record = Idval::Record->new({Record=>$rec});
    #print "Dump of record is:", Dumper($tag_record);

    foreach my $conv (@{$self->{CONVERTERS}})
    {

        if ($conv == $self->{LASTCONVERTER})
        {
            $to_file = $dest;
        }
        else
        {
            $to_type = $conv->query('to');
            $to_file = File::Temp::tmpnam() . '.' . $self->get_typemap()->get_output_ext_from_filetype($to_type);
            push(@temporary_files, $to_file);
        }

        verbose("Converting ", $tag_record->get_name(), " to $to_file using ", $conv->query('name'), "\n");
        $retval = $conv->convert($tag_record, $to_file);
        last if $retval != 0;

        $tag_record->set_name($to_file);
    }

    unlink @temporary_files;

    return $retval;
}

sub get_source_filepath
{
    my $self = shift;
    my $rec = shift;

     
    return $self->{FIRSTCONVERTER}->get_source_filepath($rec);
}

sub get_dest_filename
{
    my $self = shift;
    my $rec = shift;
    my $dest_name = shift;
    my $dest_ext = shift;

    idv_dbg("First dest name: [_1], dest ext: [_2]\n", $dest_name, $dest_ext); ##debug1
    foreach my $conv (@{$self->{CONVERTERS}})
    {
        $dest_name = $conv->get_dest_filename($rec, $dest_name, $dest_ext);
        idv_dbg("Dest name is now \"[_1]\" ([_2])\n", $dest_name, $conv->query('name')); ##debug1
    }

    return $dest_name;

}

sub get_typemap
{
    my $self = shift;

    return Idval::Common::get_common_object('typemap');
}

sub get_converters
{
    my $self = shift;

    return @{$self->{CONVERTERS}};
}

1;
