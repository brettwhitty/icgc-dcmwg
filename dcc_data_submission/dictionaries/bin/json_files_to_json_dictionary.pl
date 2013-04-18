#!/usr/bin/env perl 
#===============================================================================
#
#         FILE:  json_files_to_json_dictionary.pl
#
#        USAGE:  ./json_files_to_json_dictionary.pl  
#
#  DESCRIPTION:  Reassembles directory of files back into JSON dictionary 
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
use File::Basename qw{ basename };
use JSON;
use Cwd qw{ abs_path };

my $input;
my $output;

GetOptions(
    'input|i=s'     =>  \$input,
    'output|o=s'    =>  \$output,
);

unless (defined($input) && -d $input) {
    die "Must provide an input directory that exists with --input";
}

my $outfh;
if (! defined($output) || $output eq '') {
    $outfh = \*STDOUT;
} else {
    open $outfh, '>', $output
        or die "Failed to open '$output' for writing";
}

$input = abs_path($input);
my $version = basename($input);

my @json_files = glob("$input/*.json");

my $empty_json = qq|{"files" : [], "version" : "$version", "state" : "OPENED"}|;

my $ord = {'p' => 1, 's' => 2, 'm' => 3, '' => 1 };
my @for_sort = map {
    my $base = basename($_, '.json');
    my ($p, $s) = (split(/_/, $base), '');
    [$p, $ord->{$s}, $_]
} @json_files;

@json_files = map { $_->[2] } sort { $a->[0] cmp $b->[0] || $a->[1] <=> $b->[1] } @for_sort;

my $json_doc = decode_json($empty_json);
foreach my $json_file(@json_files) {
    print STDERR $json_file."\n";
    my $json = read_file($json_file);
    my $obj = decode_json($json);
    push(@{$json_doc->{'files'}}, $obj);
}

my $jsonp = JSON->new->allow_nonref;
my $json = $jsonp->pretty->encode($json_doc); # pretty-printing

print $outfh $json;
