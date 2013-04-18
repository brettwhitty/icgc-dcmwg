#!/usr/bin/env perl 

## Quick script to convert ICGC DCC dictionary JSON to a document.
##
## ...proper docs to be added later
##
## Brett Whitty, OICR, 2013
## brett.whitty@oicr.oicr.on.ca

$| = 1;

use strict;
use warnings;

use Cwd qw{ abs_path };
use File::Basename qw{ basename dirname};
use File::Slurp;
use JSON;
use Getopt::Long;
use Text::Autoformat;
use XML::XMLWriter;
#use HTML::Latex;
#use HTML::WikiConverter;

my $codelist_dir;
my $dictionary_json;
my $force_version;

GetOptions(
    'input|i=s'     =>  \$dictionary_json,
    'codelists|c=s' =>  \$codelist_dir,
    'version|v=s'   =>  \$force_version,
);

unless (-f $dictionary_json) {
    die "Must provide path to a dictionary JSON file with --input flag!";
}
unless (-d $codelist_dir) {
    die "Must provide path to a directory containing codelist JSON with --codelists flag!";
}

## hard coding for now until added to the JSON
my $csv = {
    'uri'               =>  1,
    'db_xref'           =>  1,
    'matched_sample_id' =>  1,
    'platform_feature_id' =>  1,
};
my $depr = {
    'note'                      =>  1,
    'donor_notes'               =>  1,
    'specimen_notes'            =>  1,
    'analyzed_sample_notes'     =>  1,
    'gene_stable_id'            =>  1,
#    'second_gene_stable_id'            =>  1,
#    'gene_build_version'        =>  1,
    'gene_name'                 =>  1,
#    'mutation_id'               =>  1,
    'start_probe_id'            =>  1,
    'end_probe_id'              =>  1,
    'antibody_id'               =>  1,
    'probeset_id'               =>  1,
    'methylated_fragment_id'    =>  1,
    'mirna_seq'                 =>  1,
    'chromosome'                =>  1,
    'chromosome_start'          =>  1,
    'chromosome_start_range'    =>  1,
    'chromosome_end'            =>  1,
    'chromosome_end_range'      =>  1,
    'chromosome_strand'         =>  1,
    'gene_chromosome'           =>  1,
    'gene_start'                =>  1,
    'gene_end'                  =>  1,
    'gene_strand'               =>  1,
#    'exon1_chromosome'          =>  1,
#    'exon1_number_bases'        =>  1,
#    'exon1_end'                 =>  1,


};

my $dictionary = from_json(read_file($dictionary_json));

### TEMP
my $dictdir = dirname(abs_path($dictionary_json));
### ^^^^

my @codelist_files = glob("$codelist_dir/*.json");

my $codes = {};
foreach my $list_file(@codelist_files) {
    
    my $list = from_json(read_file($list_file));

    foreach my $term(@{$list->{'terms'}}) {
        $codes->{$list->{'name'}}->{$term->{'code'}}->{'value'}  = $term->{'value'};
        $codes->{$list->{'name'}}->{$term->{'code'}}->{'uri'}    = $term->{'uri'} || 'N/A';
        $codes->{$list->{'name'}}->{$term->{'code'}}->{'dbxref'} = $term->{'dbxref'} || 'N/A';
    }
}

my $version = (defined($force_version)) ? $force_version : $dictionary->{'version'};
my @files   = @{$dictionary->{'files'}};

## create the HTML document
my $doc = new XML::XMLWriter(
    system => 'http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd',
    public => '-//W3C//DTD XHTML 1.0 Transitional//EN'
);

my $html = $doc->createRoot;
my $head = $html->head;

## preamble for head ## TEMP HACK
$head->_cdata(inc_html('_head.preamble'));
##

$head->title->_pcdata('ICGC DCC Submission File Specifications')->_parent()->link({
        rel     => 'stylesheet',
        type    => 'text/css',
        href    => 'css/document.css',
});

## postamble for head ## TEMP HACK
$head->_cdata(inc_html('_head.postamble'));
##

my $body = $html->body;

## preamble for body ## TEMP HACK
$body->_cdata(inc_html('_body.preamble'));
## ^^^

$body->div({'class' => 'hero-unit'})
->p->_pcdata('ICGC DCC Submission File Specifications')->_parent()
->div({'class' => 'well well-small'})
->_pcdata('Version ')
->strong({}, $version)
->_parent()
->p->em({}, "https://submissions.dcc.icgc.org/ws/dictionaries/".$version);

my $file_div = $body->div({class => 'file'});

$file_div->div({'class' => 'page-header'})->h1->_pcdata('File Specifications');

## true/false classes
my $tf_class = {
    'true'  =>  'istrue',
    'false' =>  'isfalse',
    'N/A'   =>  'isna',
};
## type classes
my $type_class = {
    'TEXT'      =>  'datatype text',
    'CV'        =>  'datatype cv',
    'DECIMAL'   =>  'datatype decimal',
    'INTEGER'   =>  'datatype integer',
};

foreach my $file(@files) {
    
    if ($file->{'role'} eq 'SUBMISSION') {
        
        my $file_type = $file->{'name'};
        my $file_label = $file->{'label'};
        my $file_regex = $file->{'pattern'};
        
        my $div = $file_div->div({class => 'file-spec'})->a({'name' => $file_type})->_parent();


    ## temporary code --- need to support in the JSON somehow as notes
#    my $file_preamble = "$file_type.preamble";
#    my $file_postamble = "$file_type.postamble";
#    my $preamble = (-f $file_preamble_path) ? read_file($file_preamble_path) : '';
#    my $postamble = (-f $file_postamble_path) ? read_file($file_postamble_path) : '';
    ##^^^

        $file_regex =~ s/\\\\/\\/g;

        ## file type heading
        $div->h2->_pcdata("File Type: '$file_label'");
        $div->h3->_pcdata("File Key: '$file_type'");
        $div->h3->_pcdata("File Name ")
        ->a({
                href => 'http://docs.oracle.com/javase/6/docs/api/java/util/regex/Pattern.html#sum',
                target => '_blank',
            }, 'Pattern')
        ->_parent()->_pcdata(": '$file_regex'");

        $div->div({'class' => 'preamble'})->_cdata(inc_html("$file_type.preamble"));

        my $table = $div->table({
                'class' =>  'table table-condensed table-hover sortable',
        }
        );

        ## headings
        my $thead = $table->thead;
        my $tr_h  = $thead->tr;

        my @headings = (
            'Data Element ID',
            'Name',
            'Description',
            'Data Type',
            'CV Codes',
            'CSV?',
            'Required?',
            'N/A Code Valid?',
            'Controlled Access?',
            'Deprecated?',
        );

        foreach my $head(@headings) {
            $tr_h->th->_pcdata($head);
        }

        my $tbody = $table->tbody;
        foreach my $field(@{$file->{'fields'}}) {
            my $is_identifier   = 0;
            my $is_required     = 'false';
            my $is_controlled   = 'false';
            my $is_deprecated   = 'false';
            my $permit_csv      = 'false';
            my $permit_null     = 'N/A';
            my $codelist        = '';
            my @row_classes     = ();

            if (ref($field) ne 'HASH') {
                use Data::Dumper;
                print STDERR Dumper $file;
                print STDERR Dumper $field;
            }

            if (! defined($field->{'label'})) {
                print STDERR "WARNING: ".$file->{'name'}.".".$field->{'name'}." has no 'label'\n";
            }

            if ($field->{'name'} =~ /_id$/ && $field->{'name'} !~ /gene_stable_id|^junct|biobank/) {
                push(@row_classes, ('identifier-element', 'success'));
                $is_identifier = 1;
            }

            ## hard coding for now until JSON supports
            if (defined($csv->{$field->{'name'}})) {
                $permit_csv = 'true';
            }
            if (defined($depr->{$field->{'name'}})) {
                ## a hack
                if ($file_type eq 'platform_annotation') {
                    if (! $field->{'name'} =~ /^gene_/) {
                        $is_deprecated = 'true';
                    }
                } else {
                    $is_deprecated = 'true';
                }
            }
           

            ## another hack
            if ($file_type eq 'jcn_p' && $field->{'name'} =~ /^gene/) {
                $is_deprecated = 'false';
            }
            ## ^^^
            
            ## another hack fix
            if ($file_type eq 'ssm_p' && $field->{'name'} =~ /^chromosome/) {
                        $is_deprecated = 'false';
            }
            ## ^^^^
            if ($field->{'controlled'} eq 'true') {
                $is_controlled   = 'true';
            }

            ## secondary files are deprecated
            ### HACK
            if ($file_type =~ /_s$/) {
                $is_deprecated = 'true';
                if ($file_type =~ /stsm_s/) {
                    $is_deprecated = 'false';
                }
            }

            foreach my $restr(@{$field->{'restrictions'}}) {

                if ($restr->{'type'} eq 'required') {
                    ## handle required
                    $is_required = 'true';
                    if ($restr->{'config'}->{'acceptMissingCode'} eq 'true') {
                        $permit_null = 'true';
                    } else {
                        $permit_null = 'false';
                    }
                } elsif ($restr->{'type'} eq 'codelist') {
                    ## handle codelist
                    $codelist = $restr->{'config'}->{'name'};
                    $field->{'valueType'} = 'CV';
                } elsif ($restr->{'type'} eq 'deprecated') {
                    $is_deprecated = $restr->{'config'}->{'isDeprecated'} || 'false';
                } elsif ($restr->{'type'} eq 'csv') {
                    $permit_csv = $restr->{'config'}->{'isValid'} || 'true';
                }
            }

            ## prepare CSS classes based on flags
            if ($is_deprecated eq 'true') {
                push(@row_classes, ('deprecated-element', 'warning'));
            } elsif ($is_required eq 'true') {
                unless($is_identifier) {
                    push(@row_classes, ('required-element', 'info'));
                }
            } else {
                push(@row_classes, ('optional-element'));
            }

            my $tr_class = join(' ', @row_classes);
            
            ## new table row
            my $tr = $tbody->tr({'class' => $tr_class.' pbi-avoid'});

            (my $name = $field->{'name'}) =~ tr/_/ /;
            name_case(\$name);

            ## ID  name  description  type  codes  required?  permit NA/UNK?  controlled  deprecated
            my $td_id = $tr->td({'class' => 'element-name'});
            add_id_link($td_id, $field->{'name'}, $file_type);
                #->_pcdata($field->{'name'});
            
            $tr->td({'class' => 'element-display-name'})->_pcdata($name || $field->{'name'} || '');
            $tr->td({'class' => 'element-description'})->small->_pcdata($field->{'description'} || $field->{'label'});
            $tr->td({'class' => $type_class->{$field->{'valueType'}}})->_pcdata($field->{'valueType'});
            
            ## need to add anchor tag here
            #$tr->td->_pcdata(codes_to_text($codelist, $codes->{$codelist}));
            codes_to_text($tr, $codelist, $codes->{$codelist});

            $tr->td({'class' => 'bool '.$tf_class->{$permit_csv}})->_cdata(bool_text($permit_csv, 'csv'));            
            $tr->td({'class' => 'bool '.$tf_class->{$is_required}})->_cdata(bool_text($is_required, 'req'));
            $tr->td({'class' => 'bool '.$tf_class->{$permit_null}})->_cdata(bool_text($permit_null, 'unk'));
            $tr->td({'class' => 'bool '.$tf_class->{$is_controlled}})->_cdata(bool_text($is_controlled, 'dac'));
            $tr->td({'class' => 'bool '.$tf_class->{$is_deprecated}})->_cdata(bool_text($is_deprecated, 'dep'));
        }
    
        $div->div({'class' => 'postamble'})->_cdata(inc_html("$file_type.postamble"));
        $div->hr;
    }
    
}
my $cv_div = $body->div({class => 'cv'});

codes_to_tables($cv_div, $codes);

## postamble for body ## TEMP HACK
$body->_cdata(inc_html('_body.postamble'));
## ^^^

#$body->b->_pcdata("END");

$doc->print();

sub codes_to_text {
    my ($tr, $list_name, $code_hash) = @_;

    my @out = ();
#    foreach my $key(sort {$a <=> $b} keys(%{$code_hash})) {
#        push(@out, $key."=\'".$code_hash->{$key}->{'value'}."\'");
#    }
    foreach my $key(sort {$a <=> $b} keys(%{$code_hash})) {
        push(@out, [$key, $code_hash->{$key}->{'value'}]);
    }
    
    my $td;
    if (scalar(@out)) {
        my @cvcode_class = ('codes');

        if (scalar(@out) > 10) {
            push(@cvcode_class, 'appendix');
        } else {
            push(@cvcode_class, 'inplace');
            
        }
        $td = $tr->td({'class' => join(' ', @cvcode_class)});
        $td->div({'class' => 'link'})
            ->_pcdata("[")
            ->a({
                   href => "#$list_name"
               },
               $list_name
            )->_parent()
            ->_pcdata("]");
        #if (scalar(@out) <= 10) {
        #     my $dl = $td->dl({'class' => 'codes-list'});
        my $dl = $td->div({'class' => 'list'})
        ->dl({'class' => 'codes-list', 'title' => $list_name});
            foreach my $code(@out) {
                $dl->dt()->_pcdata($code->[0]);
                $dl->dd()->_pcdata($code->[1]);
            }
        #}
    } elsif (scalar(@out) == 0) {
        $td = $tr->td({'class' => 'codes na'})
            ->_pcdata('N/A');
    }
}

sub codes_to_tables {
    my ($cv_div, $codes_hash) = @_;

    my @headings = (
        'ID',
        'Term',
        'DB Xref',
        'URI',
    );
    
    $cv_div->div({'class' => 'page-header'})->h1->_pcdata('Controlled Vocabulary (CV) Tables');


    foreach my $codelist(sort keys %{$codes_hash}) {
   
        my $div = $cv_div->div({class => 'cv-spec'})
                        ->a({name => $codelist})->_parent();

        $div->h2->_pcdata("CV Table: '$codelist'");
        $div->h3->_pcdata("URL: 'https://submissions.dcc.icgc.org/ws/codeLists/$codelist'");
        
        my $table = $div->table({
                'class' =>  'table table-condensed table-hover sortable', 
            }
        );

        ## headings
        my $thead = $table->thead();
        my $tr_h = $thead->tr;
        foreach my $head(@headings) {
            $tr_h->th->_pcdata($head);
        }
        my $tbody = $table->tbody();

        foreach my $id(sort {$a <=> $b} keys %{$codes_hash->{$codelist}}) {

            my $dbxref_class = ($codes_hash->{$codelist}->{$id}->{'dbxref'} eq 'N/A') ?
                'cv-dbxref isna muted' : '';
            
            my $uri_class   = ($codes_hash->{$codelist}->{$id}->{'uri'} eq 'N/A') ?
                'cv-uri isna muted' : '';

            ## new table row
            my $tr = $tbody->tr({'class' => 'pbi-avoid'});
            $tr->td({'class' => 'cv-code'})->_pcdata($id);
            $tr->td({'class' => 'cv-value'})->_pcdata($codes_hash->{$codelist}->{$id}->{'value'});
            $tr->td({'class' => $dbxref_class})->small->_pcdata($codes_hash->{$codelist}->{$id}->{'dbxref'});
            $tr->td({'class' => $uri_class})->small->_pcdata($codes_hash->{$codelist}->{$id}->{'uri'});
        }
    }
}

sub name_case {
    my ($name_ref) = @_;

    ${$name_ref} = autoformat ${$name_ref}, { case => 'highlight' };

    ${$name_ref} =~ s/(?<!\S)db(?!\S)/DB/i;
    ${$name_ref} =~ s/(?<!\S)uri(?!\S)/URI/i;
    ${$name_ref} =~ s/(?<!\S)id(?!\S)/ID/i;
    ${$name_ref} =~ s/(?<!\S)icd10(?!\S)/ICD-10/ii;
    ${$name_ref} =~ s/(?<!\S)mirna(?!\S)/miRNA/ii;
}

sub add_id_link {
    my ($elem, $name, $file_type) = @_;

    $file_type =~ s/_[ms]$/_p/;

    my $hrefs = {
        'donor_id'                  =>  'donor',
        'specimen_id'               =>  'specimen',
        'analyzed_sample_id'        =>  'sample',
        'reference_sample_id'       =>  'sample',
        'matched_sample_id'         =>  'sample',
        'platform_feature_id'       =>  'platform_annotation',
        'methylated_fragment_id'    =>  'platform_annotation',
        'start_probe_id'            =>  'platform_annotation',
        'end_probe_id'              =>  'platform_annotation',
        'platform_id'               =>  'platform_annotation',
        'feature_id'                =>  'platform_annotation',
        'analysis_id'               =>  $file_type,
        'mutation_id'               =>  $file_type,
    };

    if (defined($hrefs->{$name})) {
        $elem->a({'href' => '#'.$hrefs->{$name}})->_pcdata($name)->_parent();
    } else {
        $elem->_pcdata($name);
    }
}

sub inc_html {
    my ($where) = @_;

    my $file = $dictdir."/$where.html";
    
    if (-f $file) {
        return read_file($file);
    } else {
        return '';
    }
}

sub bool_text {
    my ($bool, $opt) = @_;

    my $opts = {
        'YES'   =>  {
            'csv'   =>  '<span class="label label-info" title="Data element supports comma-separated value list">CSV Valid</span></a>',
            'req'   =>  '<span class="label label-success" title="Data element requires a value">Required</span>',
            'unk'   =>  '<span class="label label-success" title="VALID if value set to codes -888 (N/A) or -777 (Verified Unknown)">N/A Valid</span>',
            'dac'   =>  '<span class="label label-important" title="Controlled access data element">Controlled</span>',
            'dep'   =>  '<span class="label label-warning" title="Data element is deprecated and may be dropped in future specifications revisions">Deprecated</span>',
        },
        'NO'    =>  {
            'csv'   =>  '<span class="label label-info" title="Data element does not support a comma-separated value list"></span>',
            'req'   =>  '<span class="label" title="Value optional, VALID if value is set to NULL code -999">Optional</span>',
            'unk'   =>  '<span class="label label-important" title="INVALID if value set to codes -888 (N/A) or -777 (Verified Unknown)">N/A Invalid</span>',
            'dac'   =>  '<span class="label label-success" title="Open access data element">Open Access</span>',
            'dep'   =>  '<span class="label label-warning" title="Data element is current"></span>',
        },
        'N/A'   =>  {
            'csv'   =>  '<span class="label"></span>',
            'req'   =>  '<span class="label"></span>',
            'unk'   =>  '<span class="label"></span>',
            'dac'   =>  '<span class="label"></span>',
            'dep'   =>  '<span class="label"></span>',
        },
    };

    $bool = uc($bool);
    $bool =~ s/^TRUE$/YES/g;
    $bool =~ s/^FALSE$/NO/g;

    if (defined($opt) && defined($opts->{$bool}->{$opt})) {
        return $opts->{$bool}->{$opt};
    } else {
        return 'N/A';
    }

}
