use lib '../../proj/ext/MPEG-ID3v2Tag-0.39/blib/lib';
use MPEG::ID3v2Tag;
use IO::File;

# create a tag
open(OUTFILE, ">a.bin");
binmode OUTFILE;
$tag = MPEG::ID3v2Tag->new();
$tag->add_frame( "TIT2", "Happy Little Song" );    # one step
$frame = MPEG::ID3Frame::TALB->new("Happy little album");
$tag->add_frame($frame);                           # two steps
$tag->add_frame( "WCOM", "http://www.mp3.com" );
$tag->set_padding_size(256);
print OUTFILE $tag->as_string();
close OUTFILE;

# read a tag from a file and dump out some data.
#open(FH, "<a.mp3");
$fh = IO::File->new("<a.mp3");
binmode $fh;
$tag = MPEG::ID3v2Tag->parse($fh);
for $frame ( $tag->frames() ) {
    print $frame->frameid(), "\n";    # prints TALB, TIT2, WCOM, etc.
    if ( $frame->flag_read_only() ) {
        print "  read only\n";
    }
    if ( $frame->fully_parsed() && $frame->frameid =~ /^T.../ ) {
        print "  frame text is ", $frame->text(), "\n";
    }
    if ( $frame->fully_parsed() && $frame->frameid =~ /^W.../ ) {
        print "  url is ", $frame->url(), "\n";
    }
}
