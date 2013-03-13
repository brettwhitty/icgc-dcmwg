#!/usr/bin/env perl 
#===============================================================================
#
#         FILE:  json_dictionary_to_json_files.pl
#
#        USAGE:  ./json_dictionary_to_json_files.pl  
#
#  DESCRIPTION:  Splits the JSON dictionary up into individual files 
#
#      OPTIONS:  ---
# REQUIREMENTS:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  Brett Whitty (), Brett.Whitty@oicr.on.ca
#      COMPANY:  Ontario Institute for Cancer Research
#      VERSION:  1.0
#      CREATED:  01/24/2013 10:26:53
#     REVISION:  ---
#===============================================================================

use strict;
use warnings;

use Getopt::Long;
use File::Slurp;
use File::Path;
use JSON;
use Cwd qw{ abs_path };

my $input;
my $output;

GetOptions(
    'input|i=s'     =>  \$input,
    'output|o=s'    =>  \$output,
);

unless (defined($input) && -f $input) {
    die "Must provide an input file that exists with --input";
}
unless (defined($output) && -d $output) {
    die "Must provide a directory for output with --output";
}

my $json = read_file($input);
my $obj = decode_json($json);
my $version = $obj->{'version'};
my $outpath = $output.'/'.$version;
mkpath($outpath);

foreach my $file(@{$obj->{'files'}}) {
    my $name = $file->{'name'};
   
    my $jsonp = JSON->new->allow_nonref;
    my $json = $jsonp->pretty->encode($file); # pretty-printing

    write_file($outpath.'/'.$name.'.json', $json);
}
