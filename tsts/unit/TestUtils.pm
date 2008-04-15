package TestUtils;
use Data::Dumper;
use Carp;

# Recursively get package names
sub _get_pkgs
{
    no strict 'refs';
    my $pname = shift;
    my $p = \%{$pname};

    push(@packages, $pname);
    foreach my $pkg (grep(/\:\:$/, keys %$p))
    {
        next if $pkg =~ m/^[A-Z]+\:\:$/; # Don't mess with these?

        _get_pkgs($pname . $pkg);
    }
}

sub _package2filename {
     my $package = shift;
     $package =~ s[::][/]g;
     $package =~ s{/$}{};
     $package .= '.pm';
     return $package;
}

sub _unload_package {
     my $package = shift;

     my ($stash, $dynamic);

     #print STDERR "From \"$package\"\n";
     {
         no strict 'refs';
         $stash = ($package =~ m/::$/) ? \%{$package} : \%{$package . '::'};
     }

     # Figure out if this module was dynamically loaded
     for (my $i = 0 ; $i < @DynaLoader::dl_modules ; $i++) {
         if ($DynaLoader::dl_modules[$i] eq $package) {
             $dynamic = splice(@DynaLoader::dl_librefs, $i);
             splice(@DynaLoader::dl_modules, $i);
         }
     }

     # wipe every entry in the stash except the sub-stashes
     while (my ($name, $glob) = each %$stash) {
         if ($name !~ /::$/) {
             delete $stash->{$name};
         }
     }

     # Unload the .so
     if ($dynamic) {
         DynaLoader::dl_unload_file($dynamic);
     }

     # Clear package from %INC
     #printf "About to delete \"$package\" (%s)\n", _package2filename($package);
     delete $INC{_package2filename($package)};
}

sub unload_packages
{
    my $module = shift;
    confess "unload_packages: \"module\" is undefined" unless defined($module);

    foreach my $pkg (@{$module->get_packages()})
    {
        #print STDERR "*** Unloading $pkg\n";
        _unload_package($pkg);
    }
}

sub unload_plugins
{
    my @tst_pkgnames = grep(/^tsts\/unittest.*\.pm$/, keys %INC);

    foreach my $name (@tst_pkgnames)
    {
        next if $name =~ m/TestUtils/;
        $pkg = $name;
        $pkg =~ s/\.pm//;
        $pkg =~ s{tsts/}{};

        TestUtils::_unload_package($pkg);

        delete $INC{$name} if exists $INC{$name};
    }


}

package TestUtils::FakeConfig;

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
    my @args = @_;

    $self->{ARGS} = \@args;
    $self->{ARGINDEX} = 0;
}

sub get_single_value
{
    my $self = shift;

    return ${$self->{ARGS}}[$self->{ARGINDEX}++];
}

sub get_value
{
    my $self = shift;
    my $retval = $self->{ARGS};
    return $retval;
}

sub get_value_default
{
    my $self = shift;
    my $key = shift;
    my $argref = shift;

    my $selects = exists $argref->{selects} ? $argref->{selects} : {};
    my $default = exists $argref->{default} ? $argref->{default} : [];

    return defined $self->{ARGS} ? $self->{ARGS} : $default;
}

package TestUtils::FakeConverter;

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
    my $type_mapping = shift;
    my $class_mapping = shift;

    $self->{TYPEMAP} = $type_mapping;
    $self->{CLASSMAP} = $class_mapping;
    $self->{TYPE} = (keys %{$type_mapping})[0];
}

sub query
{
    my $self = shift;
    my $qu = shift;

    return $self->{TYPE} if $qu eq 'type';
    return $self->{TYPEMAP} if $qu eq 'filetype_map';
    return $self->{CLASSMAP} if $qu eq 'classtype_map';
}

package TestUtils::FakeProvider;

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

    $self->{PROVS} = [
                      TestUtils::FakeConverter->new({'MP3' => [qw{ mp3 }]}, {'MUSIC' => [qw( MP3 )]}),
                      TestUtils::FakeConverter->new({'MP3' => [qw{ mp3 }]}, {'MUSIC' => [qw( MP3 )]}),
                      TestUtils::FakeConverter->new({'OGG' => [qw{ ogg }]}, {'MUSIC' => [qw( OGG )]}),
                      TestUtils::FakeConverter->new({'FLAC' => [qw{ flac flac16 }]}, {'MUSIC' => [qw( FLAC )]}),
                      ];
}

sub _get_providers
{
    my $self = shift;
    my @provider_types = @_;
    my @prov_list = ();

    return @{$self->{PROVS}};
}

sub get_provider
{
    my $self = shift;
    my $provider = shift;
    my $src = shift;
    my $dest = shift || 'DONE';

    return $self->{READER};
}

sub get_all_active_providers
{
    my $self = shift;
    my @types = @_;

    return @{$self->{PROVS}};
}

1;
