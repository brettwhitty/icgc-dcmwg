#!/usr/bin/perl

$| = 1;

use strict;
use warnings;

use Carp;
use Cwd qw{ abs_path }; 
use File::Basename;
use File::Find::Rule;
use File::Spec::Functions;
use Getopt::Long;
use Pod::Usage;
use PerlIO::gzip; ## not necessary but needs to be installed for gzip support
use Set::Scalar;
use Text::CSV;


## Brett Whitty, OICR, 2013

## NOTE: This script will merge files, but it is assuming that all files of the same time have at
##       least the same columns, not necessarily in the same order. It is also assuming that the files 
##       are tab-delimited text in unix file format, and are not encoded in some exotic character
##       encoding. It is also not valid in ICGC submission files to have a null ('') string as a
##       value in a column, and there is no guarantee that this script will properly handle this
##       error situation; likewise with files where columns are missing. If errors are present in
##       the input files they will be propagated, or compounded in the output files very likely
##       without warning. 


#use Date::Format;
#my @lt = localtime(time);
#my $timestamp = strftime('%Y%m%d%H%M%S', @lt);

## supported ICGC submission file types for wildcard matching
my $types = {
    'ssm'   => [qw{p m s}],
    'sgv'   => [qw{p m s}],
    'cnsm'  => [qw{p m s}],
    'cngv'  => [qw{p m s}],
    'stsm'  => [qw{p m s}],
    'stgv'  => [qw{p m s}],
    'meth'  => [qw{p m s}],
    'exp'   => [qw{g m}],
    'jcn'   => [qw{p m s}],
    'mirna' => [qw{p m s}],
    'pexp'  => [qw{p m}],
    '*'     => [qw{donor specimen sample}],
};

my $input;  ## directory containing input files to be merged
my $output; ## directory to write output files to
my $gzip;   ## support reading/writing files that are gzipped (requires PerlIO::gzip)
my $debug;
my $verbose; ## same as debug for now
my $force;

GetOptions(
    'input|i=s'     =>  \$input,
    'output|o=s'    =>  \$output,
    'gzip|z!'       =>  \$gzip,
    'debug|d!'      =>  \$debug,
    'verbose|v!'    =>  \$verbose,
    'force|f!'      =>  \$force, ## allows override of warning about no files being merged
);

## verbose == debug for now
if ($verbose) {
    $debug = 1;
}

handle_opts();

if ($debug) {
    print STDERR "Merging files in '$input'\n";
    print STDERR "Writing output to '$output'\n";
}

my $join_flag = 0;
##iterate through each file type and join
foreach my $type(keys %{$types}) {
    foreach my $subtype(@{$types->{$type}}) {
        my @files = get_files_list($input, $type, $subtype);
        use Data::Dumper;
        if (@files) {
            if ($debug) {
                print STDERR 'Merging ('.join(',', @files).")\n";
            }
            do_join($output, \@files);
            $join_flag = 1;
        }
    }
}
if (! $force && ! $join_flag) {
    do_usage('No files were merged. Check your input directory, or consider using the --gzip flag.');
}

sub do_usage{
    my ($msg) = @_;

    confess $msg;
};



## returns a list of files of specified type and subtype
sub get_files_list {
    my ($dir, $prefix, $subtype) = @_;

    my $name = $prefix.'*__'.$subtype.'__*.txt';

    if ($gzip) {
        $name .= ".gz";
    }

    if ($debug) {
        print STDERR "Finding '$name' files\n";
    }

    my @files = File::Find::Rule->file()
        ->name($name)
        ->in($dir);

    return @files;
}

## reads list of files and writes the merged file with appropriate header
## and keeping the columns in the same order
sub do_join {
    my ($dir, $files) = @_;

    my $headers = {};
    my $merged_header = Set::Scalar->new();
    my @output_header = ();

    ## check that all files have the same columns present (order can vary, but all should be present)
    foreach my $file(@{$files}) {
        
        my $infh = readfh($file);
        
        my $header = <$infh>;
        $header =~ s/\s*$//; ## chomp is unsafe because we don't know what OS the files were created on
        my @t = split(/\t/, $header);
        
        ## use the first file's header order for output (we'll check all have same columns)
        unless (scalar(@output_header)) {
            @output_header = (@t);
        }
       
        ## add headers to merged set
        $merged_header->insert(@t);

        ## store header set for this file
        my $header_set = Set::Scalar->new(@t);
        $headers->{$file} = $header_set;
    }

    ## check that all files had same header
    foreach my $file(keys %{$headers}) {
        if (! $merged_header->is_equal($headers->{$file})) {
            confess 'Header mismatch while joining files: ('.join(',', @{$files}).')';
        }
    }

    ## use the first file in the list to name merged output file
    ## (metadata in file names no longer parsed by DCC submission system)
    my $outfh = writefh(catfile($dir, basename(@{$files}[0])));
   
    ## write header to output file
    print $outfh join("\t", @output_header)."\n";

    ## iterate through all files writing line by line
    foreach my $file(@{$files}) {
        my $tsv = Text::CSV->new({
            'sep_char'  =>  "\t",
            'binary'    =>  1,
        });
        
        my $infh = readfh($file);

        my $header = <$infh>;
        $header =~ s/\s*$//; ## chomp is unsafe because we don't know what OS the files were created on
        my @t = split(/\t/, $header);

        ## set column names for Text::CSV hashref
        $tsv->column_names(@t);

        ## reorder columns if necessary to match header
        while (my $hr = $tsv->getline_hr($infh)) {
            my @row = ();
            
            foreach my $col_key(@output_header) {
                push(@row, $hr->{$col_key});
            }
            print $outfh join("\t", @row)."\n";
        }

    }
}

## open a filehandle for reading
sub readfh {
    my ($file) = @_;

    my $infh;
    
    if ($gzip) {
        open $infh, '<:gzip', $file
            or confess "Failed to open '$file' for reading: $!";
    } else {
        open $infh, '<', $file
            or confess "Failed to open '$file' for reading: $!";
    }

    return $infh;
}

## open a filehandle for writing
sub writefh {
    my ($file) = @_;

    my $outfh;
    
    if ($gzip) {
        open $outfh, '>:gzip', $file
            or confess "Failed to open '$file' for writing: $!";
    } else {
        open $outfh, '>', $file
            or confess "Failed to open '$file' for writing: $!";
    }

    return $outfh;
}

## check options that were provided
sub handle_opts {
    unless (defined($input)) {
        do_usage('Must provide an input directory containing submission files to merge with --input flag');
    }
    unless (defined($output)) {
        do_usage('Must provide an output directory to write merged files to with --output flag');
    }

    $input = abs_path($input);
    $output = abs_path($output);

    if ($input eq $output) {
        do_usage('Output and input directories can not be the same!');
    }
}
