#!/usr/bin/env perl 
#===============================================================================
#
#         FILE:  dictionary_to_files.pl
#
#        USAGE:  ./dictionary_to_files.pl  
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
use MIME::Base64;

my $input;
my $output;
my $user;
my $pass;

GetOptions(
    'input|i=s'     =>  \$input,
    'output|o=s'    =>  \$output,
    'user|u=s'      =>  \$user,
    'pass|p=s'      =>  \$pass,
);

unless (defined($input) && -d $input) {
    die "Must provide an input directory that exists with --input";
}

unless (defined($output) && -d $output) {
    die "Must provide an output directory that exists with --output";
}

unless (defined($user) && defined($pass)) {
    die "Must provide a user and password with --user / --pass flags";        
}

my $server  = 'submissions.dcc.icgc.org';
my $url     = "https://$server/ws";

my $auth    = 'X-DCC-Auth '.encode_base64("$user:$pass");
chomp $auth;

$input = abs_path($input);
$output = abs_path($input);
my $version = basename($input);

my @json_files = glob("$input/*.json");

my @codelist_names = ();
foreach my $json_file(@json_files) {
    my $json = read_file($json_file);
    my $obj = decode_json($json);

    my $file_base = basename($json_file, '.json');

    foreach my $field(@{$obj->{'fields'}}) {
        my $element_name = $field->{'name'};
        my $codelist_name = undef;
        foreach my $res(@{$field->{'restrictions'}}) {
            if ($res->{'type'} eq 'codelist') {
                $codelist_name = $res->{'config'}->{'name'};
            }
        }
        if (defined($codelist_name)) {
            push(@codelist_names, $codelist_name);            
        }
    }
}

my $outpath = "$output/codelists";
mkpath($outpath);

foreach my $name(@codelist_names) {

    my $json = `curl -k -v -XGET $url/codeLists/$name -H "Authorization: $auth" -H "Accept: application/json"`;

    my $jsonp = JSON->new->allow_nonref;
    my $obj = $jsonp->decode($json);
    $json = $jsonp->pretty->encode($obj); # pretty-printing

    write_file($outpath.'/'.$name.'.json', $json);
}
