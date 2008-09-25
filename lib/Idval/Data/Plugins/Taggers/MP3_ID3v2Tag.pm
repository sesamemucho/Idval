package Idval::SysPlugins::Taggers::MP3_ID3v2Tag;

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

#use Idval::Setup;
use strict;
use warnings;
no  warnings qw(redefine);
use Class::ISA;
use Carp;

use base qw(Idval::Plugin);

my $req_status = eval {require MPEG::ID3v2Tag};
my $req_msg = !defined($req_status) ? "$!" : 
                   $req_status == 0 ? "$@" :
                                       "Load OK";

if ($req_msg ne 'Load OK')
{
    print "Oops; let's try again for MPEG::ID3v2Tag\n";
    use lib Idval::Common::get_top_dir('lib/perl/MPEG-ID3v2Tag');

    $req_status = eval {require MPEG::ID3v2Tag};
    $req_msg = 'Load OK' if (defined($req_status) && ($req_status != 0));
}

my $name = 'MP3_ID3v2Tag';

Idval::Common::register_provider({provides=>'reads_tags', name=>$name, type=>'MP3', weight=>70});
Idval::Common::register_provider({provides=>'writes_tags', name=>$name, type=>'MP3', weight=>70});

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    bless($self, ref($class) || $class);
    $self->init();
    return $self;
}

sub init
{
    my $self = shift;

    $self->set_param('name', $self->{NAME});
    $self->set_param('dot_map', {'MP3' => [qw{ m }]});
    $self->set_param('filetype_map', {'MP3' => [qw{ mp3 }]});
    $self->set_param('classtype_map', {'MUSIC' => [qw( MP3 )]});

    $self->set_param('path', "(Perl module}");
    #$self->set_param('is_ok', $req_msg eq "Load OK");
    $self->set_param('is_ok', 0);
    if ($req_msg eq "No such file or directory")
    {
        $req_msg = "Perl module MPEG::ID3v2Tag not found";
    }

    $self->set_param('status', $req_msg);

    return;
}

sub read_tags
{
    my $self = shift;
    my $tag_record = shift;
    my $current_tag;
    my $retval = 0;
    my $fh;

    return $retval if !$self->query('is_ok');

    my $filename = $tag_record->get_value('FILE');

    undef $fh;
    open($fh, "<", $filename) || croak "Cannot open mp3 file \"$filename\" for reading: $!\n";
    binmode $fh;

    my $tag = MPEG::ID3v2Tag->parse($fh);

    foreach my $frame ($tag->frames())
    {
        if ($frame->fully_parsed())
        {
            print "Got frame $frame->frameid\n";
        }
        else
        {
            print "Frame not fully parsed\n";
        }
    }
    
    return $retval;
}

sub write_tags
{
    my $self = shift;
    my $tag_record = shift;

    return 0 if !$self->query('is_ok');

#     my $fileid = $tag_record->get_value('FILE');
#     my $exiftool = new Image::ExifTool;
#     my $vs = $self->{VISIBLE_SEPARATOR};
#     my $success;
#     my $errStr;
#     my $exif_tag;

#     foreach my $tag ($tag_record->get_all_keys())
#     {
#         # set a new value and capture any error message
#         ($exif_tag = $tag) =~ s/\Q$vs\E/ /g;
#         ($success, $errStr) = $exiftool->SetNewValue($tag, $tag_record->get_value($tag));

#         if ($errStr)
#         {
#             carp $errStr;
#             return 1;
#         }
#     }

#     $exiftool->WriteInfo($fileid);

    return 0;
}

1;
