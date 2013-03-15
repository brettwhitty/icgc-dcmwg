#!/usr/bin/env perl 
#===============================================================================
#
#         FILE:  file_template_to_json.pl
#
#        USAGE:  ./file_template_to_json.pl  
#
#  DESCRIPTION:  Processes a dictionary file template with '_include' for data elements to make JSON;
#                also supports extending via '_extend'
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
my $parent;

GetOptions(
    'input|i=s'     =>  \$input,
    'output|o=s'    =>  \$output,
    'parent!'       =>  \$parent,
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
    
    my $extensions = {};

    ## support extensions (file or hash ref) which will add / replace keyed values in the include
    if (! $parent && defined($elems->[$i]->{'_extend'})) {

        if (ref $elems->[$i]->{'_extend'} eq 'HASH') {
            $extensions = $elems->[$i]->{'_extend'};
        } else {
            my $file = $elems->[$i]->{'_extend'};
            $extensions = get_json($file);
        }
    }
    ## support file includes
    if (defined($elems->[$i]->{'_include'})) {
   
        my $file = $elems->[$i]->{'_include'};
    
        my $obj = get_json($input_dir, $file);
        
        foreach my $key(keys %{$extensions}) {
            $obj->{$key} = $extensions->{$key};
        }
    
        $elems->[$i] = $obj;
    }  
}

my $jsonp = JSON->new->allow_nonref;
$json = $jsonp->pretty->encode($obj); # pretty-printing

write_file("$output/$ftype.json", $json);

sub get_json {
    my ($input_dir, $file) = @_;

    my $json = read_file($input_dir.'/'.$file);
    
    my $obj = decode_json($json);

    return $obj; 
}
