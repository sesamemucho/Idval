package Idval::ProviderMgr;

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
#no warnings qw(redefine);
use Data::Dumper;
use Text::Abbrev;
use File::Basename;
use File::Spec;
use Memoize;
use Carp;

use Idval::Constants;
use Idval::Common;
use Idval::Converter;
use Idval::Graph;
use Idval::FileIO;

sub new
{
    my $class = shift;
    my $self = {};
    bless($self, ref($class) || $class);
    Idval::Common::register_common_object('providers', $self);
    $self->_init(@_);

    return $self;
}

sub _init
{
    my $self = shift;
    my $config = shift;
    $self->{CONFIG} = $config;
    $self->{DEFAULT_SELECTS} = {'config_group' => 'idval_settings'};
    Idval::Common::register_common_object('providers', $self);

    my $dirlist = $self->local_get_list_value('plugin_dir');
    #print "dirlist is: ", join(":", @{$dirlist}), "\n";
    #print Dumper($config);
    $self->{COMMAND_DIRS} = $self->local_get_list_value('command_dir');
    $self->{COMMAND_LIST} = {};
    $self->{COMMAND_EXT}  = $self->local_get_single_value('command_extension');

    my @provider_types = qw{converts reads_tags writes_tags command};
    $self->{NUM_PROVIDERS} = 0;
    $self->{PROVIDERS} = {};
    $self->{LOG} = Idval::Common::get_logger();
    *verbose = Idval::Common::make_custom_logger({level => $VERBOSE,
                                                  debugmask => $DBG_PROVIDERS,
                                                  decorate => 1}) unless defined(*verbose{CODE});
    *chatty = Idval::Common::make_custom_logger({level => $CHATTY,
                                                 debugmask => $DBG_PROVIDERS,
                                                 decorate => 1}) unless defined(*chatty{CODE});
    *chatty_graph = Idval::Common::make_custom_logger({level => $CHATTY,
                                                 debugmask => $DBG_GRAPH,
                                                 decorate => 1}) unless defined(*chatty_graph{CODE});
    *info    = Idval::Common::make_custom_logger({level => $INFO,
                                                  debugmask => $DBG_PROVIDERS,
                                                  decorate => 1}) unless defined(*info{CODE});

    map{$self->{GRAPH}->{$_} = Idval::Graph->new()} @provider_types;

    $self->get_plugins($dirlist);

    map{$self->{GRAPH}->{$_}->process_graph()} @provider_types;

    chatty_graph("loaded packages: ", Dumper($self->{LOADED_PACKAGES}));
    chatty_graph("TAGREADER graph: ", Dumper($self->{GRAPH}->{reads_tags}));
    chatty_graph("command graph: ", Dumper($self->{GRAPH}->{command}));
    chatty_graph("converter graph: ", Dumper($self->{GRAPH}->{converts}));

    $self->setup_command_abbreviations();

    return;
}

sub local_get_list_value
{
    my $self = shift;
    my $item = shift;

    return $self->{CONFIG}->get_list_value($item, $self->{DEFAULT_SELECTS});
}

sub local_get_single_value
{
    my $self = shift;
    my $item = shift;

    return $self->{CONFIG}->get_single_value($item, $self->{DEFAULT_SELECTS});
}

sub num_providers
{
    my $self = shift;
    return $self->{NUM_PROVIDERS};
}

#
# For example, get_provider('reads_tags', 'MP3')
# Or           get_provider('converts', 'FLAC', 'MP3')
memoize('get_provider');
sub get_provider
{
    my $self = shift;
    my $prov_type = shift;
    my $src = shift;
    my $dest = shift || 'NULL';

    my $config = $self->{CONFIG};
    my $cnv = undef;
    my $converter;
    my $graph = $self->{GRAPH}->{$prov_type};
    my @cnv_list;

    if (!(defined($src) && defined($dest) && $src && $dest))
    {
        confess "Invalid src \"$src\" or dest \"$dest\".";
    }
    #print "Looking for provider type \"$prov_type\" src \"$src\" dest \"$dest\"\n";
    my $path = $graph->get_best_path($src, $dest);
    #print STDERR "Converter graph is: ", Dumper($graph);
    #print STDERR "From $src to $dest. Path is: ", Dumper($path);
    if (defined($path))
    {
        foreach my $cnvinfo (@{$path})
        {

            my ($converter, $name) = ($$cnvinfo[1] =~ m{^(.*)::([^:]+)}x);
            my $from = $$cnvinfo[0];
            my $to = $$cnvinfo[2];
            #print STDERR "cnvinfo is <", join(", ", @{$cnvinfo}), ">\n";
            #print STDERR "converter is <$converter>\n";
            #print STDERR "name is <$name>\n";
            #$cnv = $converter->new($config, $name);
            $cnv = $self->{ALL_PROVIDERS}->{$prov_type}->{$converter}->{$name}->{"${from}:${to}"};
            push(@cnv_list, $cnv);
        }
    }

    #print "Found ", scalar(@cnv_list), " providers for $dest -> $src\n";
    if (scalar(@cnv_list) < 1)
    {
        $self->{LOG}->idv_warn("No \"$prov_type\" provider found for \"$src,$dest\"\n");
        $converter = undef;
    }
    elsif (scalar(@cnv_list) == 1)
    {
        $converter = $cnv_list[0];
    }
    else
    {
        # This will die if we smoosh something other than converters
        $converter = Idval::Converter::Smoosh->new($src, $dest, @cnv_list);
    }

    return $converter;
}

sub get_converter
{
    my $self = shift;
    my $src = shift;
    my $dest = shift;
    my $converter = $self->get_provider('converts', $src, $dest);

    return $converter;
}

sub _get_providers
{
    my $self = shift;
    my @provider_types = @_;
    my @prov_list = ();

    # For each kind of provider
    foreach my $prov_type (@provider_types)
    {
        my $provider_id = $prov_type;

        # For each provider
        foreach my $conversion (keys %{$self->{GRAPH}->{$provider_id}->{EXTRACTED_PATHS}})
        {
            my ($from, $to) = ($conversion =~ m/^([^.]+)\.([^.]+)$/x);
            #next if $from eq $to;

            push(@prov_list, $self->get_provider($prov_type, $from, $to));
        }
    }

    return @prov_list;
}

# Provides information about _all_ providers, even those that are disabled or unselected.
# Should only be used to report on configuration
sub direct_get_providers
{
    my $self = shift;
    my @provider_types = @_;
    my @prov_list = ();

    # For each kind of provider
    foreach my $prov_type (@provider_types)
    {
        foreach my $provider_package (keys %{$self->{ALL_PROVIDERS}->{$prov_type}})
        {
            foreach my $provider_name (keys %{$self->{ALL_PROVIDERS}->{$prov_type}->{$provider_package}})
            {
                foreach my $endpoint (keys %{$self->{ALL_PROVIDERS}->{$prov_type}->{$provider_package}->{$provider_name}})
                {
                    my $cnv = $self->{ALL_PROVIDERS}->{$prov_type}->{$provider_package}->{$provider_name}->{$endpoint};
                    push(@prov_list, {converter=>$cnv, name=>$provider_name, package_name=>$provider_package, type=>$prov_type, endpoint=>$endpoint});
                }
            }
        }
    }


    return map { $_->[0] }
           sort { $a->[1] cmp $b->[1] }
           map { [$_, $_->{name}] } @prov_list;
}

sub get_all_active_providers
{
    my $self = shift;

    return $self->_get_providers('reads_tags', 'writes_tags', 'converts');
}

# sub xxx_get_all_providers
# {
#     my $self = shift;
#     my %prov_list;

#     return $self->_get_providers('reads_tags', 'writes_tags', 'converts');
#     #my $graph = $self->{GRAPH}->{$prov_type};
#     foreach my $type (keys %{$self->{ALL_PROVIDERS}})
#     {
#         foreach my $pkgname (keys %{$self->{ALL_PROVIDERS}->{$type}})
#         {
#             foreach my $cnv_name (keys %{$self->{ALL_PROVIDERS}->{$type}->{$pkgname}))
#             {
#                 $prov_list{$type}->{$pkgname . '::' . $cnv_name} =
#                     $self->{ALL_PROVIDERS}->{$type}->{$pkgname}->{$cnv_name};
#             }
#         }
#     }

#     return \%prov_list;
# }

sub get_tagger
{
    my $self = shift;
    my $provider = shift;
    my $type = shift;
    my $converter = $self->get_provider($provider, $type, 'NULL');

    return $converter;
}

# sub get_command
# {
#     my $self = shift;
#     my $name = lc(shift);
#     my $retval = '';

#     if (exists($self->{CMD_ABBREVS}->{$name}))
#     {
#         my $cmd_id = $self->{CMD_ABBREVS}->{$name};

#         $retval = $self->get_provider('command', $cmd_id, 'NULL');
#     }

#     return $retval;
# }

sub _get_command
{
    my $self = shift;
    my $name = shift;
    my $filename = shift;

    return $self->{COMMAND_LIST}->{$name} if exists $self->{COMMAND_LIST}->{$name};

    my $fh = Idval::FileIO->new($filename, "r");
    confess "Bad filehandle: $! for item \"$filename\"" unless defined $fh;

    my $plugin = do { local $/ = undef; <$fh> };
    $fh->close();

    croak "Could not read plugin \"$_\"\n" unless $plugin;

    # Find package name (if any)
    # This seems like a horrible hack, is there another way?
    my $pkg = "Idval::Scripts";
    my $found_an_init = 0;

    foreach my $line (split("\n", $plugin))
    {
        $line =~ m/package\s+([\w:]+)\s*;/x and do {
            $self->{LOG}->chatty($DBG_PROVIDERS, "Found package \"$1\"\n");
            $pkg = $1;
            next;
        };

        $line =~ m/sub\s+init\s*$/x and do {
            $found_an_init = 1;
            next;
        };

        $line =~ m/sub\s+$name\s*$/x and do {
            last;
        };
    }

    my $full_name = $pkg . '::' . $name;

    my $insert = "\n# line 1 \"$filename\"\n";
    $insert .= $pkg eq "Idval::Scripts" ? 'package Idval::Scripts;' : '';
    $insert .= "\n$plugin";
    #my $status = do {eval "$insert\n$plugin" };
#    my $status = do {eval {$insert} };

    #{
     #   local $SIG{__WARN__} = sub { print "evaluating plugin \"$full_name\": $_[0]"; };
        no warnings 'redefine';
        my $status = do {eval "$insert" };

        if (defined $status)
        {
            #print STDERR "Status is <$status>\n";
        }
        else
        {
            print STDERR "Error return from \"$full_name\"\n";
        }
        if (not ($status or $! or $@))
        {
            croak "Error reading \"$full_name\": Does it return a true value at the end of the file?\n";
        }
        else
        {
            croak "Error reading \"$full_name\":($!) ($@)" unless $status;
        }

    #}
    # The first time a command is encountered, if it has an "init" routine, call it
    if ((!exists $self->{COMMAND_LIST}->{$name}) && $found_an_init)
    {
        my $init_name = $pkg . '::init';
        no strict 'refs';
        &$init_name();
        use strict;
        $self->{COMMAND_LIST}->{$name} = $full_name;
    }

    return $full_name;
}

sub find_command
{
    my $self = shift;
    my $name = shift;
    my $filename = '';
    my $ext = $self->{COMMAND_EXT};

    # We don't want to recurse to find commands, so don't use idv_find.
    # We don't want to recurse, because it should be easy for users to
    # write command scripts, and I don't want to make them put the
    # commands in leaf directories, instead of, say, their home
    # directories.
    foreach my $cmd_dir (@{$self->{COMMAND_DIRS}})
    {
        my @sources = Idval::FileIO::idv_glob("$cmd_dir/$name.$ext",
                                              $Idval::FileIO::GLOB_NOCASE | $Idval::FileIO::GLOB_TILDE);
        if (@sources)
        {
            $filename = $sources[0];
            if (scalar @sources >= 2)
            {
                $self->{LOG}->idv_warn("Multiple script files found for command ",
                                       "\"$name\": \"", join("\"\n\t\"", @sources),
                                       "\". Picking the first one.\n");
            }
            last;
        }
    }

    confess("No script file found for command \"$name\" in directories\n\t\"",
          join("\", \"", @{$self->{COMMAND_DIRS}}), "\"\n") if not $filename;


    return $self->_get_command($name, $filename);
}

sub find_all_commands
{
    my $self = shift;
    my @namelist;
    my $ext = $self->{COMMAND_EXT};

    # We don't want to recurse to find commands, so don't use idv_find.
    # We don't want to recurse, because it should be easy for users to
    # write command scripts, and I don't want to make them put the
    # commands in leaf directories, instead of, say, their home
    # directories.
    foreach my $cmd_dir (@{$self->{COMMAND_DIRS}})
    {
        my @sources = Idval::FileIO::idv_glob("$cmd_dir/*.$ext",
                                              $Idval::FileIO::GLOB_NOCASE | $Idval::FileIO::GLOB_TILDE);
        foreach my $source (@sources)
        {
            my $name = basename(lc($source), '.pm');

            $self->_get_command($name, $source);

            push(@namelist, $name);
        }
    }

    return @namelist;
}

sub make_sub
{
    my $cmd = shift;
    my $name = shift;

    my $sub = "Idval::Scripts::$name";
    no strict 'refs';
    *$sub = sub { return $cmd->$name(@_); };
    use strict;

    return;
}

sub setup_command_abbreviations
{
    my $self = shift;
    my @cmd_list;
    my $name;

    foreach my $converter ($self->_get_providers('command'))
    {
        $name = $converter->query('name');
        push(@cmd_list, $name);
        make_sub($converter, $name);
    }

    $self->{CMD_ABBREVS} = abbrev(@cmd_list);

    return;
}

sub _get_arg
{
    my $self = shift;
    my $argref = shift;
    my $keyword = shift;
    my $default = shift;
    my $retval = '';

    if (defined($argref->{$keyword}))
    {
        $retval = $argref->{$keyword};
    }
    elsif (defined($default))
    {
        $retval = $default;
    }
    else
    {
        confess "Nothing provided for \"$keyword\" in ", Dumper($argref);
    }

    return $retval;
}

sub clear_providers
{
    my $self = shift;
    %{$self->{PROVIDERS}} = ();

    return;
}

# The routine "get_packages" is needed for tsts/TestUtils.pm
sub get_packages
{
    my $self = shift;

    return [sort keys %{$self->{LOADED_PACKAGES}}];
}

sub _add_provider
{
    my $self = shift;
    my $argref = shift;

    my $prov_type  = $argref->{prov_type};
    my $package    = $argref->{package};
    my $name       = $argref->{name};
    my $src        = $argref->{src};
    my $dest       = $argref->{dest};
    my $weight     = $argref->{weight};
    my @attributes = split(',', $argref->{attributes});

    my $config = $self->{CONFIG};
    my $cnv;

    $cnv = $package->new($config, $name);
    $cnv->set_param('attributes', $argref->{attributes});
    $cnv->set_param('from', $src);
    $cnv->set_param('to', $dest);
    my $endpoint = $cnv->add_endpoint($src, $dest);

    $self->{NUM_PROVIDERS}++;
    $self->{ALL_PROVIDERS}->{$prov_type}->{$package}->{$name}->{$endpoint} = $cnv;
    if ($cnv->query('is_ok'))
    {
        #chatty("Adding \"$prov_type\" provider \"$name\" from package \"$package\". src: \"$src\", dest: \"$dest\", weight: \"$weight\"\n");
        chatty("Adding \"$prov_type\" provider: From \"$src\", via \"${package}::$name\" to \"$dest\", weight: \"$weight\" ",
               "attributes: \"", $argref->{attributes}, "\"\n");
        $self->{GRAPH}->{$prov_type}->add_edge($src, $package . '::' . $name, $dest, $weight, @attributes);
    }
    else
    {
        my $status = $cnv->query('status') ? $cnv->query('status') : 'no status';
        verbose("Provider \"$name\" is not ok: status is: $status\n");
    }

    return;
}

# A provider:
# reads tags from a file
# writes tags to a file
# converts files from (at least) one type to (at least) other type
#
# Idval::Setup::register_provider({provides=>'reads_tags', name=>'vorbistools', type=>'ogg'})
# Idval::Setup::register_provider({provides=>'reads_tags', name=>'tag', type=>'ogg'},
#                                 {provides=>'reads_tags', name=>'tag', type=>'mp3'});
# Idval::Setup::register_provider({provides=>'converts', name=>'flac', from=>'wav', to=>'flac'},
#                                 {provides=>'converts', name=>'flac', from=>'flac', to=>'wav'});

sub register_provider
{
    my $self = shift;
    my ($package) = caller(1);

    #print "Hi from register_provider, (package $package) args are: ", join(':', %{$_[0]}), "\n";
    #print "caller is: ", caller, "\n";
    #print "caller(1) is: ", caller(1), "\n";
    #print "caller(2) is: ", caller(2), "\n";
    foreach my $argref (@_)
    {
        my $provides = lc($self->_get_arg($argref, 'provides'));
        my $name     = $self->_get_arg($argref, 'name');
        # If a weighting for this provider has been specified in a config file, use that value
        my $config_weight = $self->{CONFIG}->get_single_value('weight', {'command_name'=>$name});
        # otherwise, use what the provider says... otherwise, use 100
        my $weight   = $config_weight || $self->_get_arg($argref, 'weight', 100);
        my $attributes = $self->_get_arg($argref, 'attributes', '');

        chatty("Adding \"$provides\" $package\n");
        $self->{LOADED_PACKAGES}->{$package}++;

        $provides eq 'reads_tags' and do {
            $self->_add_provider({prov_type => $provides,
                                  package => $package,
                                  name => $name,
                                  src => uc($self->_get_arg($argref, 'type')),
                                  dest => 'NULL',
                                  weight => $weight,
                                  attributes => $attributes,});
            next;
        };
        $provides eq 'writes_tags' and do {
            $self->_add_provider({prov_type => $provides,
                                  package => $package,
                                  name => $name,
                                  src => uc($self->_get_arg($argref, 'type')),
                                  dest => 'NULL',
                                  weight => $weight,
                                  attributes => $attributes,});
            next;
        };
        $provides eq 'converts' and do {
            #print STDERR "Converter registering: name is $name: $from to $to\n";
            $self->_add_provider({prov_type => $provides,
                                  package => $package,
                                  name => $name,
                                  src => uc($self->_get_arg($argref, 'from')),
                                  dest => uc($self->_get_arg($argref, 'to')),
                                  weight => $weight,
                                  attributes => $attributes,});
            next;
        };
        $provides eq 'command' and do {
            #print STDERR "Command registering: name is \"$name\": package is \"$package\"\n";
            $self->_add_provider({prov_type => $provides,
                                  package => $package,
                                  name => $name,
                                  src => $name,
                                  dest => 'NULL',
                                  weight => $weight,
                                  attributes => $attributes,});
            next;
        };

        carp "Unrecognized provider type \"$provides\" in ", Dumper($argref);
    }

    return;
}

# sub register_program
# {
#     my $self = shift;
#     my $argref = shift;
# }

# sub get_registered
# {
#     my $self = shift;
#     my $type = shift || '';
#     return $type ? $self->{PROVIDERS}->{$type} : $self->{PROVIDERS};
# }

sub get_plugin_cb
{
    my $plugin_name = $_;

    return unless $plugin_name =~ m/\.pm$/x;
    my $fh = Idval::FileIO->new($plugin_name, "r");
    confess "Bad filehandle: $! for item \"$plugin_name\"" unless defined $fh;

    # Doing it this way instead of just "do ..." to allow for use
    # of in-core files for testing (see FileString.pm)
    my $plugin = "\n# line 1 \"" . File::Spec->canonpath($plugin_name) . "\"\n";
    $plugin .= do { local $/ = undef; <$fh> };
    $fh->close();

    #print "Plugin is \"$plugin\"\n" if $plugin_name eq "id3v2";
#     croak "Could not read plugin \"$plugin_name\"\n" unless $plugin;

    #print STDERR "Plugin $plugin_name\n";
    #my $status = do {eval "$plugin" };
    ##my $status = do "$plugin_name";
    #{
      #  local $SIG{__WARN__} = sub { print "evaluating plugin \"$plugin_name\": $_[0]"; };
        no warnings 'redefine';
        my $status = eval "$plugin";
        ###my $status = eval {$plugin};
        #print STDERR "eval result is: $@\n" if $@;
        if (defined $status)
        {
            chatty($DBG_STARTUP, "Status is <$status>\n");
        }
        else
        {
            info($DBG_STARTUP, "Error return from \"$plugin_name\"\n");
        }
        if (not ($status or $! or $@))
        {
            croak "Error reading \"$plugin_name\": Does it return a true value at the end of the file?\n";
        }
        else
        {
            croak "Error reading \"$plugin_name\":($!) ($@)" unless $status;
        }
    #}

    return;
}

sub get_plugins
{
    my $self = shift;
    my $dirlist = shift;

    #print STDERR "In get_plugins, looking into \"", join(':', @{$dirlist}), "\"\n";
    Idval::FileIO::idv_find(\&get_plugin_cb, @{$dirlist});
    # Each plugin should self-register

    return;
}

# sub get_command_cb
# {
#     return unless $_ =~ m/\.pm$/;
#     my $fh = Idval::FileIO->new($_, "r");
#     confess "Bad filehandle: $! for item \"$_\"" unless defined $fh;

#     my $plugin = do { local $/; <$fh> };
#     $fh->close();

#     croak "Could not read plugin \"$_\"\n" unless $plugin;


#     my $status = do {eval "$plugin" };

#     if (defined $status)
#     {
#         #print STDERR "Status is <$status>\n";
#     }
#     else
#     {
#         print STDERR "Error return from \"$_\"\n";
#     }
#     if (not ($status or $! or $@))
#     {
#         croak "Error reading \"$_\": Does it return a true value at the end of the file?\n";
#     }
#     else
#     {
#         croak "Error reading \"$_\":($!) ($@)" unless $status;
#     }
# }

# sub get_plugins
# {
#     my $self = shift;
#     my $dirlist = shift;
#     my $status;

#     #print STDERR "In get_plugins called with dirlist = ", join(",", @{$dirlist}), "\n";
#     #print STDERR Carp::longmess("get_plugins called...");
# DIRS: foreach my $dir (@{$dirlist})
#     {
#         #print STDERR "In dir $dir\n";
#     FILES: foreach my $file (glob($dir . '/*.pm'))
#         {
#             #print STDERR "Reading file $file\n";
#             $status = do $file;
#             #print STDERR "Status is <$status>\n";
#             croak "Error reading \"$file\":" . $@ unless $status;
#         }
#     }

#     # Each plugin should self-register
# }

#memoize('get_plugins');

1;
