package Idval::Setup;

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
#use strict;
#use warnings;

use Filter::Util::Call;
#use File::Basename;

#my %providers;

sub import
{
    my($type) = @_ ;
    filter_add(bless []) ;
}

sub filter
{
    my($self) = @_ ;
    my($status) ;
    print STDERR "Filter:\n";
    s/Joe/Jim/g
        if ($status = filter_read()) > 0 ;
    $status ;
}

# sub import
# {
#     my($type, @arguments) = @_;
#     my %top;
#     my $linenum = 0;
#     $top{linenum} = 0;
#     $top{packagename} = '';
#     filter_add(\%top);

#     print STDERR "HELLO FROM IMPORT\n";
#     return;
# }

# sub filter
# {
#     print STDERR "HELLO FROM FILTER\n";
#     my($self) = @_;
#     my($status);
#     my ($caller, $file, $line) = caller(0);
#     $line++;
#     my $location = qq{\n#line $line "$file"\n};

#     if ($self->{linenum} <= 0)
#     {
#         $_ .= "my \$fuff = 1;\n" .
#                     $location;

# #         $_ .= "use strict;\nuse warnings;\n" .
# #             "no warnings qw(redefine);\n" .
# #             "print STDERR \"file is $file\\\n\";\n" .
# #                     $location;
#         #"local $SIG{__WARN__} = sub { print 'evaluating plugin ', $file , ': ', $_[0]; };\n"
#         # Put other Idval packages here
#         #print STDERR "package name is $packname\n";
#         print STDERR "First lines: <$_>\n";
#     }

#     $status = filter_read();

#     if ($status > 0)
#     {
#         ++ $self->{linenum};
#     }

#     #print STDERR "XX: $self->{linenum}, \"$_\"\n";
#     return $status;
# }

# This version does too much
# our %module_list;

# sub import
# {
#     my($type, @arguments) = @_;
#     my %top;
#     my $linenum = 0;
#     $top{linenum} = 0;
#     $top{packagename} = '';
#     filter_add(\%top);
# }

# sub filter
# {
#     my($self) = @_;
#     my($status);
#     my ($caller, $file, $line) = caller(0);
#     $line++;
#     my $location = qq{\n#line $line "$file"\n};

#     if ($self->{linenum} <= 0)
#     {
#         my $filename = basename($file, ".pm");
#         my $dirname = basename(dirname($file));
#         my $packname = 'Idval::' . $dirname . '::' . ucfirst($filename);
#         $self->{packagename} = $packname;
#         $_ .= "package $packname;\nuse strict;\nuse warnings;\n" .
#                     $location;
#         #print STDERR "package name is $packname\n";
#         #print STDERR "First lines: <$_>\n";
#     }

#     $status = filter_read();

#     if ($status <= 0)
#     {
#         add_module($self->{packagename}, $file);
#     }
#     else
#     {
#         ++ $self->{linenum};
#     }

#     #print STDERR "XX: $self->{linenum}, \"$_\"\n";
#     $status;
# }

# sub add_module
# {
#     my $modname = shift;
#     my $filename = shift;

#     $module_list{$modname} = $filename;
# }

# sub loaded_modules
# {
#     return \%module_list;
# }


1;
