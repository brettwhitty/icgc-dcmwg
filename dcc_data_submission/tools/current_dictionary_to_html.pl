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

use File::Temp qw{ tempfile };
use File::Slurp;
use JSON;
use MIME::Base64;
use Getopt::Long;
use LWP;
use XML::XMLWriter;
#use HTML::Latex;
#use HTML::WikiConverter;

## certificate is not currently valid
$ENV{'PERL_LWP_SSL_VERIFY_HOSTNAME'} = 0;

my $user;
my $pass;

GetOptions(
    'user|u=s'      =>  \$user,
    'pass|p=s'      =>  \$pass,
);

unless (defined($user) && defined($pass)) {
    die "Must provide a user and password with --user / --pass flags";        
}

my $server = 'submissions.dcc.icgc.org';

my $dicts_url = 'https://'.$server.'/ws/dictionaries';
my $codes_url = 'https://'.$server.'/ws/codeLists';

my $auth = 'X-DCC-Auth '.encode_base64("$user:$pass");
chomp $auth;

my $content_type = 'application/json';
my $accept       = 'application/json';
  
my $ua = LWP::UserAgent->new();

$ua->default_header('Authorization' => $auth);
$ua->default_header('Content-Type'  => $accept);
$ua->default_header('Accept'        => $content_type);

my $content;
my $json;
my $response;

$content = '';
$response = $ua->get($dicts_url, ':content_cb', \&handle_content );

$json = from_json($content);

my $dictionary = undef;
foreach my $dict(@{$json}) {
    if ($dict->{'state'} eq 'OPENED') {
        $dictionary = $dict;
        last;
    }
}

$content = '';
$response = $ua->get($codes_url, ':content_cb', \&handle_content );
$json = from_json($content);

my $codes = {};
foreach my $list(@{$json}) {
    foreach my $term(@{$list->{'terms'}}) {
        $codes->{$list->{'name'}}->{$term->{'code'}} = $term->{'value'};
    }
}

my $version = $dictionary->{'version'};
my @files   = sort {$a->{'name'} cmp $b->{'name'}} @{$dictionary->{'files'}};

## create the HTML document
my $doc = new XML::XMLWriter(
    system => 'http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd',
    public => '-//W3C//DTD XHTML 1.0 Transitional//EN'
);

my $html = $doc->createRoot;

$html->head->title->_pcdata('ICGC DCC Submission File Specifications');

my $body = $html->body;
$body->h1->_pcdata('Specifications version: '.$version);

$body->h2->_pcdata('File Specifications');

foreach my $file(@files) {
    if ($file->{'role'} eq 'SUBMISSION') {

        my $file_type = $file->{'name'};
        
        ## file type heading
        $body->h3->_pcdata($file_type);

        my $table = $body->table({
                align => 'center', 
                cellspacing => 1, 
                cellpadding => 2, 
                border => 1}
        );

        ## headings
        my $tr_h = $table->tr;
        $tr_h->th->_pcdata('Data Element');
        $tr_h->th->_pcdata('Description');
        $tr_h->th->_pcdata('Data Type');
        $tr_h->th->_pcdata('Code List');
        $tr_h->th->_pcdata('Required?');

        foreach my $field(@{$file->{'fields'}}) {
            my $is_required = 'true';
            my $codelist = '';

            if (! defined($field->{'label'})) {
                print STDERR "WARNING: ".$file->{'name'}.".".$field->{'name'}." has no 'label'\n";
            }

             
            foreach my $restr(@{$field->{'restrictions'}}) {

                if ($restr->{'type'} eq 'required') {
                    ## handle required
                    if ($restr->{'config'}->{'acceptMissingCode'} eq 'true') {
                        $is_required = 'false';
                    }
                } elsif ($restr->{'type'} eq 'codelist') {
                    ## handle codelist
                    $codelist = $restr->{'config'}->{'name'};
                }
            }
            ## new table row
            my $tr = $table->tr;
            
            ## name  label  type  codes  required?
            $tr->td->_pcdata($field->{'name'});
            $tr->td->_pcdata($field->{'label'} || '');
            $tr->td->_pcdata($field->{'valueType'});
            $tr->td->_pcdata(codes_to_text($codelist, $codes->{$codelist}));
            $tr->td->_pcdata(uc($is_required));
        }
    }
    
}

#$body->b->_pcdata("END");
$doc->print();

#my $wc = new HTML::WikiConverter( dialect => 'Confluence' );
#print $wc->html2wiki( $doc->get() );

sub handle_content {
    my ($data) = @_;

    $content .= $data;
}


sub codes_to_text {
    my ($list_name, $code_hash) = @_;

    my @out = ();
    foreach my $key(sort {$a <=> $b} keys(%{$code_hash})) {
        push(@out, $key."=\'".$code_hash->{$key}."\'");
    }

    if (scalar(@out) > 10) {
        return "(see '$list_name')";
    } elsif (scalar(@out) == 0) {
        return 'N/A';
    } else {
        return join('; ', @out);
    }
}
