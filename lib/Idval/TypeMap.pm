package Idval::TypeMap;

use strict;
use warnings;
use Data::Dumper;
use English '-no_match_vars';

use Idval::Logger qw(idv_dbg fatal);

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
    my $prov = shift;
    my $vs = shift || $prov->local_get_single_value('visible_separator');

    $self->{VISIBLE_SEPARATOR} = $vs;

    $self->build_type_mapper($prov);

    #idv_dbg("TypeMap: FILETYPE map is: [_1]", Dumper($self->{MAPPING}->{FILETYPE}));
    return;
}

sub _build_map
{
    my $self = shift;
    my $converter = shift;
    my $maptype = shift;
    my $param = shift;

    $self->{MAPPING}->{$maptype} = {} unless exists $self->{MAPPING}->{$maptype};

    # Now, build up the filename to media type map
    my $mapper = $converter->query($param);
    if (defined $mapper and $mapper)
    {
        foreach my $key (keys %{$mapper})
        {
            foreach my $ext (@{$mapper->{$key}})
            {
                # Should probably put some kind of check to make sure
                # types and extensions are defined consistently and
                # uniquely.
                # Fwd is (for example) MUSIC -> {MP3=>1, FLAC=>1}, or 
                # FLAC -> {FLAC=>1, FLAC16=>1}
                # Rev is MP3 -> MUSIC, MP3 (file extension) -> MP3 (file type)
                $self->{MAPPING}->{$maptype}->{FWD}->{uc($key)}->{uc($ext)}++;
                $self->{MAPPING}->{$maptype}->{REV}->{uc($ext)} = uc($key);
            }
        }
    }

    return;
}

# Ask each tag reader and writer for its file extension -> file type mapping,
# and save it.
sub build_type_mapper
{
    my $self = shift;
    my $prov = shift;
    my $result = [];
    my $converter;

    fatal("Undefined provider object") unless defined($prov);
    # For each provider
    foreach my $provider ($prov->get_all_active_providers())
    {
        # Build up the media type to filename map
        $self->_build_map($provider, 'FILETYPE', 'filetype_map');
        # Build up the class type to media type map
        $self->_build_map($provider, 'CLASSTYPE', 'classtype_map');
        # Build up the media type to display-dot type map
        $self->_build_map($provider, 'DOTTYPE', 'dot_map');
        # Build up the media type to preferred output extension map
        $self->_build_map($provider, 'OUTPUTEXTTYPE', 'output_ext_map');
    }

    #print Dumper($self->{MAPPING}->{OUTPUTEXTTYPE});

    # Build CLASS - EXT mapping
    foreach my $class ($self->get_all_classes())
    {
        foreach my $filetype (keys %{$self->{MAPPING}->{CLASSTYPE}->{FWD}->{$class}})
        {
            foreach my $ext (keys %{$self->{MAPPING}->{FILETYPE}->{FWD}->{$filetype}})
            {
                $self->{MAPPING}->{CLASSEXT}->{FWD}->{$class}->{$ext}++;
                $self->{MAPPING}->{CLASSEXT}->{REV}->{$ext} = $class;
            }
        }
    }

    return;
}

sub get_all_classes
{
    my $self = shift;

    return sort (keys %{$self->{MAPPING}->{CLASSTYPE}->{FWD}});
}

sub get_all_filetypes
{
    my $self = shift;

    return sort (keys %{$self->{MAPPING}->{FILETYPE}->{FWD}});
}

sub get_all_extensions
{
    my $self = shift;

    return map {lc $_} sort (keys %{$self->{MAPPING}->{CLASSEXT}->{REV}});
}

sub get_filetypes_from_class
{
    my $self = shift;
    my $class = shift;

    return map {uc $_} sort (keys %{$self->{MAPPING}->{CLASSTYPE}->{FWD}->{$class}});
}

sub get_dot_map
{
    my $self = shift;
    my %dotmap;
    my $dot;

    foreach my $filetype ($self->get_all_filetypes())
    {
        if(exists($self->{MAPPING}->{DOTTYPE}->{FWD}->{$filetype}))
        {
            $dot = (keys %{$self->{MAPPING}->{DOTTYPE}->{FWD}->{$filetype}})[0];
            $dotmap{$filetype} = lc($dot);
        }
        else
        {
            $dotmap{$filetype} = '?';
        }
    }

    return \%dotmap;
}

sub get_exts_from_filetype
{
    my $self = shift;
    my $filetype = uc(shift);

    return map {lc $_} sort (keys %{$self->{MAPPING}->{FILETYPE}->{FWD}->{$filetype}});
}

# For when we just want the output extension
sub get_output_ext_from_filetype
{
    my $self = shift;
    my $filetype = uc(shift);
    # If the converter has expressed a preference for the output extension, use that.
    # Otherwise, use whatever we get from the filetype map. If no preference has been
    # given, the filetype map _should_ have only one extension per type. To put it
    # another way, if there is more than one extension per filetype, the converter
    # should set a preference for an output extension.
    my $pref_ext = exists($self->{MAPPING}->{OUTPUTEXTTYPE}->{FWD}->{$filetype}) ? 
        lc((keys %{$self->{MAPPING}->{OUTPUTEXTTYPE}->{FWD}->{$filetype}})[0]) : '';
    return $pref_ext || ($self->get_exts_from_filetype($filetype))[0];
}

sub get_exts_from_class
{
    my $self = shift;
    my $class = uc(shift);

    return map {lc $_} sort (keys %{$self->{MAPPING}->{CLASSEXT}->{FWD}->{$class}});
}

sub get_class_from_filetype
{
    my $self = shift;
    my $filetype = uc(shift);

    return $self->{MAPPING}->{CLASSTYPE}->{REV}->{$filetype};
}

# The extension is presumed to be a known extension
sub get_class_and_type_from_ext
{
    my $self = shift;
    my $ext = uc(shift);

    return ($self->{MAPPING}->{CLASSEXT}->{REV}->{$ext},
            $self->{MAPPING}->{FILETYPE}->{REV}->{$ext});
}

# The extension is not guaranteed to be known.
sub get_filetype_from_file
{
    my $self = shift;
    my $file = shift;

    my $vis_sep = $self->{VISIBLE_SEPARATOR};
    my ($ext) = ($file =~ m/\.([^.]+)$/);
    $ext =~ s/\Q${vis_sep}\E.*$//;
    $ext = uc($ext);

    idv_dbg("TypeMap::get_filetype_from_file: ext is \"[_1]\"\n", $ext);
    return exists($self->{MAPPING}->{FILETYPE}->{REV}->{$ext}) ? $self->{MAPPING}->{FILETYPE}->{REV}->{$ext} : '';
}

1;
