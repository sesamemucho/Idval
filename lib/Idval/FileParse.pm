package Idval::FileParse;

#
# XXX unused?
#
# # Copyright 2008 Bob Forgey <rforgey@grumpydogconsulting.com>

# # This file is part of Idval.

# # Idval is free software: you can redistribute it and/or modify
# # it under the terms of the GNU General Public License as published by
# # the Free Software Foundation, either version 3 of the License, or
# # (at your option) any later version.

# # Idval is distributed in the hope that it will be useful,
# # but WITHOUT ANY WARRANTY; without even the implied warranty of
# # MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# # GNU General Public License for more details.

# # You should have received a copy of the GNU General Public License
# # along with Idval.  If not, see <http://www.gnu.org/licenses/>.

# use strict;
# use warnings;
# use Data::Dumper;
# use English '-no_match_vars';
# use Carp;
# use Text::Balanced qw (
#                        extract_delimited
#                        extract_multiple
#                       );

# use Idval::FileIO;
# use Idval::Select;
# use IO::String;

# # Given a reader object and one or more IO::Handles, parse
# # the input file(s) and call reader to handle the results.

# sub new
# {
#     my $class = shift;
#     my $self = {};
#     bless($self, ref($class) || $class);
#     $self->_init(@_);
#     return $self;
# }

# sub _init
# {
#     my $self = shift;
#     my $reader = shift;
#     my @fh_list;
#     my $fh;

#     # FileParse accepts both file handles and file names
#     foreach my $item (@_)
#     {
#         next unless $item;      # Blank input file names are OK...
#         $fh = Idval::FileIO->new($item, "r");

#         confess "Bad filehandle: $! for item \"$item\"" unless defined $fh;
#         push(@fh_list, $fh);
#     }

#     $self->{READER} = $reader;
#     $self->{FILES} = \@fh_list;

#     $self->{OP_REGEX} = Idval::Select::get_op_regex();
# #     #$self->{KEYWORD_SET} = $reader->get_keyword_set();
# #     my @op_set = map(quotemeta, keys %Idval::Select::compare_function);
# #     my @ops_that_dont_need_spaces = grep(/\\/, @op_set);
# #     my @ops_that_need_spaces = grep(!/\\/, @op_set);
# #     # Sort in reverse order of length so that (for instance) 'foo =~ boo' doesn't
# #     # get matched as (foo)(=)(~ boo)
# #     my $op_string_no_spaces = join('|',  sort {length($b) <=> length($a)} @ops_that_dont_need_spaces);
# #     my $op_string_with_spaces = join('|',  sort {length($b) <=> length($a)} @ops_that_need_spaces);
# #     #print STDERR "op_string_no_spaces is: \"$op_string_no_spaces\"\n";
# #     #print STDERR "op_string_with_spaces is: \"$op_string_with_spaces\"\n";
# #     $self->{OP_REGEX_NO_SPACES} = qr/$op_string_no_spaces/;
# #     $self->{OP_REGEX_WITH_SPACES} = qr/$op_string_with_spaces/;

#     #print STDERR Dumper($self->{FILES});

#     return;
# }

# sub parse
# {
#     my $self = shift;
#     my ($ex, $text, $pref, $opening, $block, $closing);
#     my $reader = $self->{READER};

#     $text = '';

#     foreach my $fh (@{$self->{FILES}})
#     {
#         $text .= "\n" . do { local $/ = undef; <$fh> } . "\n";
#         $fh->close();
#     }

#     croak "Need a file\n" unless $text; # We do need at least one config file

#     $text =~ s/\#.*$//mgx;      # Remove comments
#     $text =~ s/^\n+//sx;         # Trim off newline(s) at start
#     $text =~ s/\n+$//sx;         # Trim off newline(s) at end

#     $self->{BLOCKS} = $reader->collection_type() eq 'HASH' ? {} : [];
#     # Blocks are separated by one or more blank lines
#     foreach my $block ($reader->get_blocks($text))
#     {
#         my $temp_block = $self->parse_block($block);
#         $reader->add_block($self->{BLOCKS}, $temp_block);
#     }

# #     # If we didn't find any blocks, something is very wrong
# #     if ((!defined($self->{BLOCKS})) || (scalar(@{$self->{BLOCKS}}) == 0))
# #     {
# #         croak "No blocks found during file parsing.";
# #     }

#     return $self->{BLOCKS};
# }

# sub parse_block
# {
#     my $self = shift;
#     my $text = shift;
#     my $reader = $self->{READER};
#     #my $kw_set = $self->{KEYWORD_SET};
# #     my $op_regex_no = $self->{OP_REGEX_NO_SPACES};
# #     my $op_regex_spaces = $self->{OP_REGEX_WITH_SPACES};
#     my $op_regex = $self->{OP_REGEX};

#     my $current_tag = '';
#     my $current_op = '';
#     my $value;
#     $reader->start_block($text);

#     #print STDERR "Block; parsing \"$text\"\n";
#     foreach my $line (split(/\n/x, $text))
#     {
#         chomp $line;
#         $line =~ s{\r}{}gx;
#         $line =~ s/\#.*$//x;      # Remove comments
#         next if $line =~ m/^\s*$/x;

#         if ($line =~ m{^([[:alnum:]]\w*)($op_regex)(\S.*)\s*$}imx)
#         {
#             #print STDERR "Got plain tag of \"$1\" \"$2\" \"$3\" \n";
#             $current_tag = $1;
#             $current_op = $2;
#             $value = $3;

#             $current_op =~ s/\ //gx;
#             $reader->store_value($current_op, $current_tag, $value);
#             next;
#         }

# #         $line =~ m{^([[:alnum:]]\w*)\s+($op_regex_spaces)\s+(\S.*)\s*$}imx and do {
# #             #print STDERR "Got plain tag of \"$1\" \"$2\" \"$3\" \n";
# #             $reader->store_value($2, $1, $3);
# #             $current_tag = $1;
# #             $current_op = $2;
# #             next;
# #         };

# #         $line =~ m{^([[:alnum:]]\w*)\s*($op_regex_no)\s*(\S.*)\s*$}imx and do {
# #             #print STDERR "Got plain tag of \"$1\" \"$2\" \"$3\" \n";
# #             $reader->store_value($2, $1, $3);
# #             $current_tag = $1;
# #             $current_op = $2;
# #             next;
# #         };

#         if ($line =~ m{^([[:alnum:]]\w*)\s*\+=\s*(\S.*)\s*$}imx)
#         {
#             #print STDERR "Got add-on tag of \"$1\" += \"$2\"\n";
#             $reader->store_value('+=', $1, $2);
#             $current_tag = $1;
#             $current_op = '+=';
#             next;
#         }

# #         $line =~ m{^($kw_set)\s+([[:alnum:]]\w*)\s*(\S+)\s*(\S.*)\s*$}imx and do {
# #             #print STDERR "Got keyword of \"$1 $2\" $3 \"$4\"\n";
# #             $reader->store_keyword_value($1, $2, $3, $4);
# #             $current_tag = $2;
# #             $current_op = $3;
# #             next;
# #         };

#         if ($current_tag eq '')
#         {
#             croak "A continuation line was found, but nothing to continue from!\nA configuration ".
#                 "assignment must start at the beginning of a line (no spaces).\nThe line in " .
#                 "question is: \"$line\"\n";
#         }

#         # Otherwise, it must be a continuation
#         $line =~ s/^\s+//x;
#         $reader->store_value($current_op, $current_tag, $line);

#      }

#     return $reader->get_block();
# }

1;
