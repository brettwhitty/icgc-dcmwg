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
$| = 1;

use strict;
use warnings;

use Getopt::Long;
use JSON;
use File::Slurp;
use File::Basename qw{ basename dirname };
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

my $template_prefix = undef;
if (basename($input) =~ /^([a-z_]+\.)?[a-z_]+\.\d+\.tmpl\.json$/i) {
    $template_prefix = $1;
} else {
    die "Expecting template files to have suffix '.#.tmpl.json'";
}

$input = abs_path($input);
print STDERR "## $input\n";
$output = abs_path($output);
my $input_dir = dirname($input);

my $json = read_file($input);

my $obj = decode_json($json);
my $ftype = $obj->{'name'};

my $elems = [@{$obj->{'fields'}}];
my $elem_count = scalar @{$elems};
for (my $i = 0; $i < $elem_count; $i++) {
    $elems->[$i] = deref_elem($elems->[$i]);
}

$obj->{'fields'} = $elems;

my $jsonp = JSON->new->allow_nonref;
$json = $jsonp->pretty->encode($obj); # pretty-printing

write_file("$output/$template_prefix$ftype.json", $json);

## given an array reference of JSON-derived hash references
## will iterate through and for each has will process:
##
## '_include'
##      to import a set of key-value pairs from a hash in an external JSON file 
## '_extend'
##      to add or over-ride key values imported by an '_include' with a referenced hash or file
## 
sub deref_elem {

    my ($elem) = @_;

    my $extensions = {};

    ## support extensions (file or hash ref) which will add / replace keyed values in the include
    if (defined($elem->{'_extend'})) {

        if (ref $elem->{'_extend'} eq 'HASH') {
            $extensions = $elem->{'_extend'};
        } else {
            my $file = $elem->{'_extend'};
            $extensions = get_json($file);
        }
    }
    ## support file includes
    if (defined($elem->{'_include'})) {
   
        my $file = $elem->{'_include'};
    
        my $obj = get_json($input_dir, $file);
     
        ## do a recursive call here to support includes
        ## and extensions in elements
        if (defined($obj->{'_include'}) || defined($obj->{'_extend'})) {
            $obj = deref_elem($obj);
        }

        foreach my $key(keys %{$extensions}) {
            $obj->{$key} = $extensions->{$key};
        }
    
        $elem = $obj;
    }  
    return $elem;
}


sub get_json {
    my ($input_dir, $file) = @_;

    my $json = read_file($input_dir.'/'.$file);
    
    my $obj = decode_json($json);

    return $obj; 
}
