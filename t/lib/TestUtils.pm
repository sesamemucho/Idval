package TestUtils;
use strict;
use warnings;

use Data::Dumper;
use Carp;

use Idval::Config;
# # Recursively get package names
# # sub _get_pkgs
# # {
# #     no strict 'refs';
# #     my $pname = shift;
# #     my $p = \%{$pname};
# #     use strict;

# #     push(@packages, $pname);
# #     foreach my $pkg (grep {/\:\:$/} keys %$p)
# #     {
# #         next if $pkg =~ m/^[A-Z]+\:\:$/; # Don't mess with these?

# #         _get_pkgs($pname . $pkg);
# #     }

# #     return;
# # }

# sub _package2filename {
#      my $package = shift;
#      $package =~ s[::][/]g;
#      $package =~ s{/$}{};
#      $package .= '.pm';
#      return $package;
# }

# ## no critic (ProhibitPackageVars)

# sub unload_one_package {
#      my $package = shift;

#      my ($stash, $dynamic);

#      #print STDERR "From \"$package\"\n";
#      {
#          no strict 'refs';
#          $stash = ($package =~ m/::$/) ? \%{$package} : \%{$package . '::'};
#      }

#      # Figure out if this module was dynamically loaded
#      for (my $i = 0 ; $i < @DynaLoader::dl_modules ; $i++) {
#          if ($DynaLoader::dl_modules[$i] eq $package) {
#              $dynamic = splice(@DynaLoader::dl_librefs, $i);
#              splice(@DynaLoader::dl_modules, $i);
#          }
#      }

#      # wipe every entry in the stash except the sub-stashes
#      while (my ($name, $glob) = each %$stash) {
#          if ($name !~ /::$/) {
#              delete $stash->{$name};
#          }
#      }

#      # Unload the .so
#      if ($dynamic) {
#          DynaLoader::dl_unload_file($dynamic);
#      }

#      # Clear package from %INC
#      #printf "About to delete \"$package\" (%s)\n", _package2filename($package);
#      delete $INC{_package2filename($package)};

#     return;
# }

# sub unload_packages
# {
#     my $module = shift;

#     if (defined($module))
#     {
#         foreach my $pkg (@{$module->get_packages()})
#         {
#             #print STDERR "*** Unloading $pkg\n";
#             unload_one_package($pkg);
#         }
#     }
#     else
#     {
#         carp "unload_packages: module arg is undefined";
#     }

#     return;
# }

# sub unload_plugins
# {
#     my @tst_pkgnames = grep {/^tsts\/unittest.*\.pm$/} keys %INC;
#     my $pkg;

#     foreach my $name (@tst_pkgnames)
#     {
#         next if $name =~ m/TestUtils/;
#         $pkg = $name;
#         $pkg =~ s/\.pm//;
#         $pkg =~ s{tsts/}{};

#         TestUtils::unload_one_package($pkg);

#         delete $INC{$name} if exists $INC{$name};
#     }

#     return;
# }

sub run_test_and_get_log
{
    my $obj = shift;
    my $fname = shift;
    my @args = @_;

    my $eval_status;
    my $str_buf = 'nothing here';

    open my $oldout, ">&STDOUT"     or die "Can't dup STDOUT: $!";
    close STDOUT;
    open STDOUT, '>', \$str_buf or die "Can't redirect STDOUT: $!";
    select STDOUT; $| = 1;      # make unbuffered

    #Idval::Logger::get_logger()->str('a_u');
    my $old_settings = Idval::Logger::get_settings();
    Idval::Logger::re_init({log_out => 'STDOUT'});

    my $result = eval{$obj->$fname(@args)};

    $eval_status = $@ if $@;

    #print STDERR "eval status is \"$@\"\n";
    Idval::Logger::re_init($old_settings);

    open STDOUT, ">&", $oldout or die "Can't dup \$oldout: $!";

    my $retval = $eval_status ? $eval_status : $str_buf;
    return wantarray ? ($result, $retval, $str_buf) : $retval;
}

sub setup_Config
{
    my $rest = shift || '';

    Idval::FileString::idv_add_file('/testdir/gt1.txt', "\nprovider_dir = /testdir/Idval\n\n" . $rest);
    my $fc = Idval::Config->new("/testdir/gt1.txt");

    return $fc;
}

sub add_Provider
{
    my $argref = shift;
    my $prov = $argref->{provides};
    my $type = exists $argref->{type} ? $argref->{type} : '';
    my $name = $argref->{name};
    my $from = exists $argref->{from} ? uc $argref->{from} : '';
    my $to =   exists $argref->{to} ? uc $argref->{to} : '';
    my $weight = exists $argref->{weight} ? $argref->{weight} : undef;
    my @attributes = exists $argref->{attributes} ? @{$argref->{attributes}} : ();

    my $lc_from = lc $from;
    my $lc_to = lc $to;
    my $attr_str = 
        @attributes ? "attributes=>'" . join(',', @attributes) . "'" :
        '';
    my $weight_str = defined $weight ? ", weight=>$weight" : '';

    # There must be $type or ($from, $to)
    my $map_str = '{';
    foreach my $item ($type, $from, $to)
    {
        next unless $item;
        $map_str .= "$item => [qw{". lc $item . "}],\n";
    }
    $map_str .= '}';

    my $plugin =<<EOF;
package Idval::Plugins::$name;
use Idval::Common;
use Data::Dumper;
use base qw(Idval::Converter);
no warnings qw(redefine);

Idval::Common::register_provider({provides=>'$prov', type=>'$type', name=>'$name', from=>'$from', to=>'$to' $weight_str});

sub new
{
    my \$class = shift;
    my \$self = \$class->SUPER::new(@_);
    bless(\$self, ref(\$class) || \$class);
    \$self->_init(@_);
    return \$self;
}

sub _init
{
    my \$self = shift;

    \$self->set_param('name', q{$name});
    if (q{$name} ne 'copy') {
    \$self->set_param('filetype_map', $map_str);
    \$self->set_param('classtype_map', {'MUSIC' => [qw( $from $to $type )]});
    \$self->set_param('from', q{$from});
    \$self->set_param('to', q{$to});}
    \$self->set_param('is_ok', 1);
}

sub gubber
{
    my \$self = shift;
    print STDERR "gubber says: ", Dumper(\$self);
}

# # I really don't know why I have to do this, since 'set_param' and 'query' work.
# sub get_source
# {
#     my \$self = shift;
#     return \$self->query('from');
# }
1;
EOF

    #print STDERR "/testdir/Idval/$name.pm is: <", $plugin, ">\n";
    Idval::FileString::idv_add_file("/testdir/Idval/$name.pm", $plugin);

    return $plugin;
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

    return;
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

    return;
}

sub query
{
    my $self = shift;
    my $qu = shift;

    return $self->{TYPE} if $qu eq 'type';
    return $self->{TYPEMAP} if $qu eq 'filetype_map';
    return $self->{CLASSMAP} if $qu eq 'classtype_map';

    return;
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

    return;
}

sub local_get_single_value
{
    my $self = shift;

    return '%%';
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
