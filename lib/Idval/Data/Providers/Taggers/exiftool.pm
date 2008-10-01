package Idval::SysPlugins::Taggers::Exiftool;

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

use base qw(Idval::Provider);

my $req_status = eval {require Image::ExifTool};
my $req_msg = !defined($req_status) ? "$!" : 
                   $req_status == 0 ? "$@" :
                                       "Load OK";

if ($req_msg ne 'Load OK')
{
    print "Oops; let's try again for Image::ExifTool\n";
    use lib Idval::Common::get_top_dir('lib/perl/Image-ExifTool');

    $req_status = eval {require Image::ExifTool};
    $req_msg = 'Load OK' if (defined($req_status) && ($req_status != 0));
}

my $name = 'exiftool';

foreach my $type (qw(JPEG TIFF RAW))
{
    Idval::Common::register_provider({provides=>'reads_tags',  name=>$name, type=>$type, weight=>50});
    Idval::Common::register_provider({provides=>'writes_tags', name=>$name, type=>$type, weight=>50});
}

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
    $self->set_param('dot_map', {'JPEG' => [qw{ j }],
                                 'TIFF' => [qw{ t }],
                                 'RAW'  => [qw{ r }]});
    $self->set_param('filetype_map', {'JPEG' => [qw{ jpg jpeg }],
                                      'TIFF' => [qw( tiff )],
                                      'RAW'  => [qw( raw  )]});
    $self->set_param('classtype_map', {'IMAGE' => [qw( JPEG TIFF RAW)]});

    $self->set_param('path', "(Perl module}");
    $self->set_param('is_ok', $req_msg eq "Load OK");
    if ($req_msg eq "No such file or directory")
    {
        $req_msg = "Perl module Image::ExifTool not found";
    }

    $self->set_param('status', $req_msg);

    my $config = Idval::Common::get_common_object('config');
    $self->{VISIBLE_SEPARATOR} = $config->get_single_value('visible_separator', {'config_group' => 'idval_settings'});

    return;
}

sub read_tags
{
    my $self = shift;
    my $tag_record = shift;
    my $line;
    my $current_tag;
    my $retval = 0;
    my %options;

    return $retval if !$self->query('is_ok');

    #print "exif: hi!\n";
    if (!exists($self->{WRITEABLE_TAGS}))
    {
        # This takes a while, so only do it (once) if we need it
        $self->{WRITEABLE_TAGS} = [Image::ExifTool::GetWritableTags()];
        #print "Found ", scalar @{$self->{WRITEABLE_TAGS}}, " writable tags\n";
    }

    my $filename = $tag_record->get_value('FILE');
    my $exiftool = new Image::ExifTool;
    #print "exif: new exiftool\n";
    my $vs = $self->{VISIBLE_SEPARATOR};

    # Extract meta information from an image
    #my $info = $exiftool->ImageInfo($filename, $self->{WRITEABLE_TAGS}, \%options);
    my $info = $exiftool->ImageInfo($filename, \%options);
    #my $success = $exiftool->ExtractInfo($filename);
    #print "exif: after extractinfo\n";
    #my $info = $exiftool->GetInfo();
    #print "exif: got image info\n";
    #my $status = $exiftool->ExtractInfo($filename, $self->{WRITEABLE_TAGS}, \%options);

    # Get list of tags in the order they were found in the file
    #my @taglist = $exiftool->GetFoundTags('Alpha');

    my @taglist = $exiftool->GetTagList($info);
    #print "exif: got tag list\n";
    foreach my $tag (@taglist)
    {
        # Get the value of a specified tag
        my $value = $exiftool->GetValue($tag, 'PrintConv');
        next unless defined($value);
        if ((ref $value eq 'ARRAY') || (ref $value eq ''))
        {
            $tag =~ s/ /\Q$vs\E/g;
            $tag_record->add_tag($tag, $value);
        }
        #print "exif: tag \"$tag\"\n";
        # Can't deal with it otherwise
    }

    return $retval;
}

sub write_tags
{
    my $self = shift;
    my $tag_record = shift;

    return 0 if !$self->query('is_ok');

    my $fileid = $tag_record->get_value('FILE');
    my $exiftool = new Image::ExifTool;
    my $vs = $self->{VISIBLE_SEPARATOR};
    my $success;
    my $errStr;
    my $exif_tag;

    foreach my $tag ($tag_record->get_all_keys())
    {
        # set a new value and capture any error message
        ($exif_tag = $tag) =~ s/\Q$vs\E/ /g;
        ($success, $errStr) = $exiftool->SetNewValue($tag, $tag_record->get_value($tag));

        if ($errStr)
        {
            carp $errStr;
            return 1;
        }
    }

    $exiftool->WriteInfo($fileid);

    return 0;
}

1;
