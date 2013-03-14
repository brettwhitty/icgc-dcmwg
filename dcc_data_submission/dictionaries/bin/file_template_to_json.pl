#!/usr/bin/env perl 
#===============================================================================
#
#         FILE:  file_template_to_json.pl
#
#        USAGE:  ./file_template_to_json.pl  
#
#  DESCRIPTION:  Processes a dictionary file template with '_include' for data elements to make JSON.
#
#      OPTIONS:  ---
# REQUIREMENTS:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  Brett Whitty (), Brett.Whitty@oicr.on.ca
#      COMPANY:  Ontario Institute for Cancer Research
#      VERSION:  1.0
#      CREATED:  02/27/2013 08:44:22
#     REVISION:  ---
#===============================================================================

use strict;
use warnings;

use Getopt::Long;
use JSON;
use File::Slurp;
use File::Basename qw{ dirname };
use Cwd qw{ abs_path };

my $input;
my $output;

GetOptions(
    'input|i=s'     =>  \$input,
    'output|o=s'    =>  \$output,
);

unless (defined($input) && -f $input) {
    die "Must provide input file with --input";
}

unless (defined($output) && -d $output) {
    die "Must provide output dir with --output";
}

unless ($input =~ /\.\d+\.tmpl\.json$/) {
    die "Expecting template files to have suffix '.#.tmpl.json'";
}

$input = abs_path($input);
$output = abs_path($output);
my $input_dir = dirname($input);

my $json = read_file($input);

my $obj = decode_json($json);
my $ftype = $obj->{'name'};

my $elems = $obj->{'fields'};
my $elem_count = scalar @{$elems};

for (my $i = 0; $i < $elem_count; $i++) {
    
    if (defined($elems->[$i]->{'_include'})) {
    
        my $file = $elems->[$i]->{'_include'};
        delete $elems->[$i]->{'_include'};
    
        my $json = read_file($input_dir.'/'.$file);
    
        my $obj = decode_json($json);
    
        $elems->[$i] = $obj;
    }
}

my $jsonp = JSON->new->allow_nonref;
$json = $jsonp->pretty->encode($obj); # pretty-printing

write_file("$output/$ftype.json", $json);
