#!/usr/bin/env perl 
#===============================================================================
#
#         FILE:  build_data_element_json.pl
#
#        USAGE:  ./build_data_element_json.pl  
#
#  DESCRIPTION:  Script to allow quick building of JSON document for data element from command line
#
#      OPTIONS:  ---
# REQUIREMENTS:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  Brett Whitty (), Brett.Whitty@oicr.on.ca
#      COMPANY:  Ontario Institute for Cancer Research
#      VERSION:  1.0
#      CREATED:  03/14/2013 17:41:06
#     REVISION:  ---
#===============================================================================

use strict;
use warnings;

use Getopt::Long;
use JSON;

my $name;
my $label;
my $is_required;
my $permit_null;
my $codelist;
my $summary;
my $type;
my $is_controlled;

GetOptions(
    'name|n=s'      =>  \$name,
    'label|l=s'     =>  \$label,
    'type|t=s'      =>  \$type,
    'summary|s=s'   =>  \$summary,
    'codelist|c=s'  =>  \$codelist,
    'required|r!'   =>  \$is_required,
    'controlled|x!' =>  \$is_controlled,
    'null|u!'       =>  \$permit_null,
);

my $types = {
    'INTEGER'   =>  1,
    'FLOAT'     =>  1,
    'TEXT'      =>  1,
};

my $summaries = {
    'UNIQUE_COUNT'  =>  1,
    'FREQUENCY'     =>  1,
    'AVERAGE'       =>  1,
};

unless (defined($types->{$type})) {
    die "Supported types are:\n".join("\n", keys %{$types})."\n";
}
if (defined($summary) && ! defined($summaries->{$summary})) {
    die "Supported summaries are:\n".join("\n", keys %{$summaries})."\n";
}

my $controlled_bool = ($is_controlled) ? JSON::true : JSON::false;
my $null_bool = ($permit_null) ? JSON::true : JSON::false;

my $obj = {
    'name'          =>  $name,
    'label'         =>  $label,
    'valueType'     =>  $type,
    'controlled'    =>  $controlled_bool,
    'summaryType'   =>  $summary || JSON::null,
    'restrictions'  => [],
};

if ($is_required) {
    my $restriction = {
        'type'  =>  'required',
    };

    $restriction->{'config'} = {'acceptMissingCode' => $null_bool};

    push(@{$obj->{'restrictions'}}, $restriction);
}

if (defined($codelist)) {
    my $restriction = {
        'type'  =>  'codelist',
    };

    $restriction->{'config'} = {'name' => $codelist};
    
    push(@{$obj->{'restrictions'}}, $restriction);
}


my $jsonp = JSON->new->allow_nonref;
my $json = $jsonp->pretty->encode($obj); # pretty-printing

print $json."\n";
