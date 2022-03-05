use inc::Module::Install;

# Define metadata
name           'Idval';
license        'gpl';
all_from       'lib/Idval.pm';

# Specific dependencies
requires       'File::Spec'  => '0.80';
test_requires  'Test::More'  => '0.42';
#recommends     'Text::CSV_XS'=> '0.50';
recommends     'MP3::Tag'    => '0';
recommends     'Image::ExifTool' => '0';
tests_recursive;
install_script 'bin/idv';

#TESTS => ['t/*.t', 't/lib/*.t', 't/accept/*.t'];

WriteAll;
