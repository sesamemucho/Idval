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

use Idval::Logger qw(:vars info verbose chatty idv_warn fatal);
use Idval::Common;
use Idval::Converter;
use Idval::Graph;
use Idval::FileIO;
use Idval::Provider;
use Idval::Command;

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

    $self->{PROVIDER_DIRS} = $self->local_get_list_value('provider_dir');
    #print "dirlist is: ", join(":", @{$dirlist}), "\n";
    #print Dumper($config);
    $self->{COMMAND_DIRS} = $self->local_get_list_value('command_dir');
    $self->{COMMAND_LIST} = {};
    $self->{COMMAND_EXT}  = $self->local_get_single_value('command_extension', 'pm');

    my @provider_types = qw{converts reads_tags writes_tags command};
    $self->{NUM_PROVIDERS} = 0;
    $self->{PROVIDERS} = {};
#     $self->{LOG} = Idval::Common::get_logger();
#     *verbose = Idval::Common::make_custom_logger({level => $VERBOSE,
#                                                   decorate => 1}) unless defined(*verbose{CODE});
#     *chatty = Idval::Common::make_custom_logger({level => $CHATTY,
#                                                  decorate => 1,
#                                                 }) unless defined(*chatty{CODE});
    *chatty_graph = Idval::Common::make_custom_logger({level => $L_CHATTY,
                                                       package => 'Idval::Graph',
                                                       decorate => 1}) unless defined(*chatty_graph{CODE});
#     *info    = Idval::Common::make_custom_logger({level => $INFO,
#                                                   decorate => 1}) unless defined(*info{CODE});

    map{$self->{GRAPH}->{$_} = Idval::Graph->new()} @provider_types;

    $self->find_all_providers();
    $self->find_all_commands();

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
    my $default = shift || '';

    return $self->{CONFIG}->get_single_value($item, $self->{DEFAULT_SELECTS}, $default);
}

sub num_providers
{
    my $self = shift;
    return $self->{NUM_PROVIDERS};
}

#
# For example, get_provider('reads_tags', 'MP3')
# Or           get_provider('converts', 'FLAC', 'MP3')
#
# Look up a plugin, given the type, the source, and the
# destination. For plugins for which a destination is not relevant (for
# instance, tag readers), the destination defaults to 'NULL'. It is
# possible that there may be more than one plugin that matches the
# input triplet (type, source, destination). In this case, the routine
# chooses the plugin with the lowest weight. The routine will also
# attempt to construct a plugin that satisfies the triplet, if
# necessary. For instance, if a caller requests a plugin to convert
# from 'FLAC' to 'MP3', but we only have converters for 'FLAC' to
# 'WAV' and 'WAV' to 'MP3', get_provider will return a plugin that
# uses these converters to convert from 'FLAC' to 'MP3' (this only
# works for converters).

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
        fatal("Invalid src \"$src\" or dest \"$dest\".");
    }
    #print STDERR "Looking for provider type \"$prov_type\" src \"$src\" dest \"$dest\"\n";
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
            my $endpoint = Idval::Provider::make_endpoint($from, $to);
            #print STDERR "cnvinfo is <", join(", ", @{$cnvinfo}), ">\n";
            #print STDERR "converter is <$converter>\n";
            #print STDERR "name is <$name>\n";
            #$cnv = $converter->new($config, $name);
            chatty("Looking up \{$prov_type\}->\{$converter\}->\{$name\}->\{$endpoint\}\n");
            $cnv = $self->{ALL_PROVIDERS}->{$prov_type}->{$converter}->{$name}->{$endpoint};
            #print STDERR "cnv is: ", Dumper($cnv) if $src eq 'about';
            push(@cnv_list, $cnv);
        }
    }

    #print STDERR "Found ", scalar(@cnv_list), " providers for $dest -> $src\n";
    if (scalar(@cnv_list) < 1)
    {
        idv_warn("No \"$prov_type\" provider found for \"$src,$dest\"\n");
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
        #print STDERR "_get_providers: For provider type \"$prov_type\"\n";
        # For each provider
        foreach my $conversion (keys %{$self->{GRAPH}->{$provider_id}->{EXTRACTED_PATHS}})
        {
            #print STDERR "_get_providers: Checking conversion \"$conversion\"\n";
            my ($from, $to) = ($conversion =~ m/^([^.]+)\.([^.]+)$/x);

            push(@prov_list, $self->get_provider($prov_type, $from, $to));
        }
    }

    return @prov_list;
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
        fatal("Nothing provided for \"$keyword\" in ", Dumper($argref));
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

    my $added = 0;
    my $config = $self->{CONFIG};
    my $cnv;
    my $endpoint = Idval::Provider::make_endpoint($src, $dest);

    if (!exists ($self->{ALL_PROVIDERS}->{$prov_type}->{$package}->{$name}->{$endpoint}))
    {
        if ($prov_type eq 'command')
        {
            $cnv = Idval::Command->new($config, $name, $package);
        }
        else
        {
            $cnv = $package->new($config, $name);
        }

        $cnv->set_param('attributes', $argref->{attributes});
        $cnv->set_param('from', $src);
        $cnv->set_param('to', $dest);
        $cnv->add_endpoint($src, $dest);

        $self->{NUM_PROVIDERS}++;
        $self->{ALL_PROVIDERS}->{$prov_type}->{$package}->{$name}->{$endpoint} = $cnv;
        if ($cnv->query('is_ok'))
        {
            chatty("Adding \{$prov_type\}->\{$package\}->\{$name\}->\{$endpoint\}\n");
            chatty("Adding \"$prov_type\" provider: From \"$src\", via \"${package}::$name\" to \"$dest\", weight: \"$weight\" ",
                   "attributes: \"", $argref->{attributes}, "\"\n");
            $self->{GRAPH}->{$prov_type}->add_edge($src, $package . '::' . $name, $dest, $weight, @attributes);
            $added = 1;
        }
        else
        {
            my $status = $cnv->query('status') ? $cnv->query('status') : 'no status';
            verbose("Provider \"$name\" is not ok: status is: $status\n");
        }
    }

    return $added;
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
        chatty("register_provider: argref is: ", Dumper($argref));
        my $provides = lc($self->_get_arg($argref, 'provides'));
        my $name     = $self->_get_arg($argref, 'name');
        # If a weighting for this provider has been specified in a config file, use that value
        my $config_weight = $self->{CONFIG}->get_single_value('weight', {'command_name'=>$name});
        # otherwise, use what the provider says... otherwise, use 100
        my $weight   = $config_weight || $self->_get_arg($argref, 'weight', 100);
        my $attributes = $self->_get_arg($argref, 'attributes', '');
        # If the caller has specified a package, use it (i.e., registering a command)
        $package = $self->_get_arg($argref, 'package', $package);

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

#         $provides eq 'command' and do {
#             #print STDERR "Command registering: name is $name: $from to $to\n";
#             $self->_add_provider({prov_type => $provides,
#                                   package => $package,
#                                   name => $name,
#                                   src => $name,
#                                   dest => 'NULL',
#                                   weight => $weight,
#                                   attributes => $attributes,});
#             next;
#         };

        fatal("Unrecognized provider type \"$provides\" in ", Dumper($argref));
    }

    return;
}

sub _load_plugin
{
    my $self = shift;
    my $filename = shift;

    return $self->{PLUGIN_LIST}->{$filename} if exists $self->{PLUGIN_LIST}->{$filename};

    my $fh = Idval::FileIO->new($filename, "r");
    fatal("Bad filehandle: $! for item \"$filename\"") unless defined $fh;


    # Doing it this way instead of just "do ..." to allow for use
    # of in-core files for testing (see FileString.pm)
    my $plugin = "\n# line 1 \"" . File::Spec->canonpath($filename) . "\"\n";
    $plugin .= do { local $/ = undef; <$fh> };
    $fh->close();

    my $package_name;
    # Is this an Idval plugin?
    if ($plugin =~ m/^\s*package\s+(Idval::Plugin[:\w]+)/mx)
    {
        $package_name = $1;
    }
    else
    {
        verbose("Plugin candidate \"$filename\" is not an Idval plugin: no \"package Idval::Plugin::...\"\n");
        return;
    }


    #print "Plugin is \"$plugin\"\n" if $filename eq "id3v2"; # or whatever...
    #fatal("Could not read plugin \"$filename\"\n") unless $plugin;
    chatty("Plugin $filename\n");

    no warnings 'redefine';
    # This call causes a Provider plugin to call 'register_provider'
    my $status = eval "$plugin";
    #print STDERR "eval result for \"$package_name\" is: $@\n" if $@;
    #print STDERR "eval result for \"$package_name\" is: \"$@\"; status is \"$status\"\n";
#     if ($package_name eq 'Idval::Plugins::Command::Gettags')
#     {
#         print STDERR "package hash for Idval::Plugins::Command::Gettags is:", Dumper(\%Idval::Plugins::Command::Gettags::);
#     }
    if (defined $status)
    {
        chatty("Status is <$status>\n");
    }
    else
    {
        info("Error return from \"$filename\"\n");
    }
    if (not ($status or $! or $@))
    {
        fatal("Error reading \"$filename\": Does it return a true value at the end of the file?\n");
    }
    else
    {
        fatal("Error reading \"$filename\":($!) ($@)") unless $status;
    }

    $self->{PLUGIN_LIST}->{$filename} = $package_name;
    return $package_name;
}

sub find_all_plugins
{
    my $self = shift;
    my $dirlist = shift;
    my $handler = shift;

    my $ext = $self->{COMMAND_EXT};

    fatal("No plugin file extension defined?") unless $ext;
    # We don't want to recurse to find providers, so don't use idv_find.
    # We don't want to recurse, because it should be easy for users to
    # write command scripts, and I don't want to make them put the
    # commands in leaf directories, instead of, say, their home
    # directories.
    foreach my $dir (@{$dirlist})
    {
        my @sources = Idval::FileIO::idv_glob("$dir/*.$ext",
                                              $Idval::FileIO::GLOB_NOCASE | $Idval::FileIO::GLOB_TILDE);
        chatty("ProviderMgr: in \"$dir\", candidates are: ", join(', ', @sources), "\n");
        foreach my $source (@sources)
        {
            next if $source =~ m/\.?\.$/;
            #$self->_load_plugin($source);
            &$handler($source);
        }
    }

    return;
}

sub find_all_providers
{
    my $self = shift;

    $self->find_all_plugins($self->{PROVIDER_DIRS}, sub{$self->_load_plugin(@_);});

    return;
}

# Command handling

#
# Providers are required to call 'register_provider' when they are
# loaded. Commands do not have this requirement, so we need to do it
# for them.
#
# To fit into the provider framework, a command is considered to be a
# provider with src=<command name> and dest=NULL. The weight is
# arbitrary, since it is never used, and there are no attributes
# (currently).
sub _get_command
{
    my $self = shift;
    my $filename = shift;

    my $package = $self->_load_plugin($filename);
    if ($package)
    {
        my $name = basename(lc($filename), '.' . $self->{COMMAND_EXT});

        #print STDERR "Command registering \"$filename\" into \"$package\": name is $name: $name to NULL\n";
        my $added = $self->_add_provider({prov_type => 'command',
                                          package => $package,
                                          name => $name,
                                          src => $name,
                                          dest => 'NULL',
                                          weight => 100,
                                          attributes => '',});
    }

    return $package;
}

sub find_all_commands
{
    my $self = shift;

    $self->find_all_plugins($self->{COMMAND_DIRS}, sub{$self->_get_command(@_);});

    return;
}

sub setup_command_abbreviations
{
    my $self = shift;

    $self->{CMD_ABBREV} = abbrev map {lc $_->{NAME}} ($self->_get_providers('command'));

    return;
}

# Look up command, allowing abbreviations
# If a command (or abbreviation) is not found, return undef.
sub get_command
{
    my $self = shift;
    my $name = lc shift;

    return unless exists($self->{CMD_ABBREV}->{$name});

    my $cmd_name = $self->{CMD_ABBREV}->{$name};
    return $self->get_provider('command', $cmd_name, 'NULL');
}

# For reporting and queries

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

1;
