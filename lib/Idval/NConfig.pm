package Idval::NConfig;

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
use English '-no_match_vars';
use Carp;
use Memoize;

use JSON;

use Idval::Common;
use Idval::Constants;
use Idval::Select;
use Idval::FileIO;

use constant STRICT_MATCH => 0;
use constant LOOSE_MATCH  => 1;

our $octothorpe = "\x23";

sub evaluate
{
    my $node = shift;
    my $select_list = shift;

    my $retval = 1;
    my $dupval;

    # We can pass in a Record as a selector
    $select_list = $select_list->get_selectors() if ref $select_list eq 'Idval::Record';

    if (ref $select_list ne 'HASH')
    {
        confess "Selector list must be a HASH\n";
    }

   my  %selectors = %{$select_list};

    # Special case
    if (!%selectors and $self->{USK_OK})
    {
        verbose("Eval: returning 1 since no selectors\n");
        return 1;
    }

    #chatty("In node \"", $self->myname(), "\"\n");
    #print Dumper($self) unless $self->myname();

    # No 'selects' in this node => everything is OK
    return 1 if not exists($node->{'selects'});

    foreach my $key (keys %selectors)
    {
        chatty("Checking select key \"$key\" with a value of \"$selectors{$key}\"\n");
        if (!exists($node->{selects}->{$key}))
        {

blah blah etc.  Got to here

            chatty("Got null key \"$key\". USK_OK is: $self->{USK_OK}\n");
            if ($self->{USK_OK})
            {
                next;
            }
            else
            {
                $retval = 0;
                last;
            }
        }

        my $sel_value = $selectors{$key};
        my $cmp_op = $self->get_select_op($key);
        my $cmp_value = $self->get_select_value($key);
        my $cmpfunc = $Idval::Select::compare_function{$cmp_op}->{FUNC}->{STR};
        chatty("Comparing \"$cmp_value\" \"$cmp_op\" \"$sel_value\" resulted in ",
                &$cmpfunc($sel_value, $cmp_value) ? "True\n" : "False\n");
        my $cmp_result = &$cmpfunc($sel_value, $cmp_value);

        if (!$cmp_result)
        {
            $retval = 0;
            last;
        }
    }

    return $retval;
}

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
    my $initfile = shift;
    my $unmatched_selector_keys_ok = shift;
    $unmatched_selector_keys_ok = LOOSE_MATCH unless defined($unmatched_selector_keys_ok);
    *verbose = Idval::Common::make_custom_logger({level => $VERBOSE, 
                                                  debugmask => $DBG_CONFIG,
                                                  decorate => 1}) unless defined(*verbose{CODE});
    *chatty  = Idval::Common::make_custom_logger({level => $CHATTY,
                                                  debugmask => $DBG_CONFIG,
                                                  decorate => 1}) unless defined(*chatty{CODE});

    $self->{OP_REGEX} = Idval::Select::get_op_regex();
    $self->{ASSIGN_OP_REGEX} = Idval::Select::get_assign_regex();
    $self->{CMP_OP_REGEX} = Idval::Select::get_cmp_regex();
    $self->{INITFILES} = [];
    $self->{TREE} = {};

    $self->add_file($initfile, $unmatched_selector_keys_ok);
}

sub add_file
{
    my $self = shift;
    my $initfile = shift;
    my $unmatched_selector_keys_ok = shift;
    $unmatched_selector_keys_ok = LOOSE_MATCH unless defined($unmatched_selector_keys_ok);

    print "Adding file \"$initfile\"\n";
    return unless $initfile;      # Blank input file names are OK...

    my $fh = Idval::FileIO->new($fname, "r") || croak "Can't open \"$fname\" for reading: $!\n";
    my $text .= do { local $/; <$fh> };
    $fh->close();

    croak "Need a file\n" unless $text; # We do need at least one config file

    $text =~ s/${octothorpe}.*$//mg;      # Remove comments

    my $obj = jsonToObj($text);

    print "obj: ", Dumper($obj);

    $self->{TREE} = $obj;


}

sub merge_blocks
{
    my $self = shift;
    my $selects = shift;
    my %vars;

    verbose("Start of _merge_blocks, selects: ", Dumper($selects));

    # visit each node, in correct order
    # if node evaluates to TRUE,
    #    accumulate values (including appends)

    # When finished with tree, return hash of values

    my $visitor = sub {
        my $node = shift;

        return undef if evaluate_node($node, $selects) == 0;

        foreach my $name (@{$node->get_assignment_data_names()})
        {
            my ($op, $value) = $node->get_assignment_data_values($name);
            chatty("name \"$name\" op \"$op\" value \"$value\"\n");

            if ($op eq '=')
            {
                chatty("For \"$name\", op is \"=\" and value is \"$value\"\n");
                $vars{$name} = $value;
            }
            elsif ($op eq '+=')
            {
                chatty("For \"$name\", op is \"+=\" and value is \"$value\"\n");
                $vars{$name} = make_flat_list($vars{$name}, $value);
            }
        }
    };

    $self->visit($self->{TREE}, $visitor);

    chatty("Result of merge blocks - VARS: ", Dumper(\%vars));

    return \%vars;
}




1;

