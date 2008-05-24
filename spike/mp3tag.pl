use FindBin;
use lib '$FindBin::Bin/../../proj/ext/MPEG-ID3v2Tag-0.39/lib';
use lib '$FindBin::Bin/../../proj/ext/MPEG-ID3v2Tag-0.39/lib';
use MPEG::ID3v2Tag;
use IO::File;
use Data::Dumper;

# create a tag
open(OUTFILE, ">a.bin");
binmode OUTFILE;
$tag = MPEG::ID3v2Tag->new();
#$tag->add_frame( "TIT2", "Happy Little Song" );    # one step
$tag->add_frame( "TIT2", "Gak" );    # one step
#$frame = MPEG::ID3Frame::TALB->new("Happy little album");
$frame = MPEG::ID3Frame::TALB->new("Glob");
$tag->add_frame($frame);                           # two steps
$tag->add_frame( "WCOM", "http://www.mp3.com" );
$tag->add_frame( "TXXX", 0, "foofah", "hoohah");
$tag->add_frame( "TXXX", 0, "Googah", "gubbers");
$tag->set_padding_size(256);
print OUTFILE $tag->as_string();
close OUTFILE;

# read a tag from a file and dump out some data.
#open(FH, "<a.mp3");
$fh = IO::File->new("<a.mp3");
binmode $fh;
$tag = MPEG::ID3v2Tag->parse($fh);
#print "tag: ", Dumper($tag);
for $frame ( $tag->frames() ) {
    print $frame->frameid(), "\n\n";    # prints TALB, TIT2, WCOM, etc.
    if ( $frame->flag_read_only() ) {
        print "  read only\n";
    }
    if ( $frame->fully_parsed() && $frame->frameid =~ /^T.../ ) {
        print "  frame text is ", $frame->text(), "\n";
        print " text frame dump:\n";
        $frame->dump();
    }
    if ( $frame->fully_parsed() && $frame->frameid =~ /^W.../ ) {
        print "  url is ", $frame->url(), "\n";
    }
}
