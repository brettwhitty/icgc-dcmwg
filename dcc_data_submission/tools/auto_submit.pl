#!/usr/bin/env perl 
#===============================================================================
#
#         FILE:  auto_submit.pl
#
#        USAGE:  ./auto_submit.pl  
#
#  DESCRIPTION:  
#
#      OPTIONS:  ---
# REQUIREMENTS:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  Brett Whitty (), Brett.Whitty@oicr.on.ca
#      COMPANY:  Ontario Institute for Cancer Research
#      VERSION:  1.0
#      CREATED:  02/19/2013 10:23:56
#     REVISION:  ---
#===============================================================================

$| = 1;
$ENV{'PERL_LWP_SSL_VERIFY_HOSTNAME'} = 0;

use strict;
use warnings;

use Cwd qw{ abs_path };
use Carp;
use DateTime;
use Getopt::Long;
use JSON;
use LWP;
use MIME::Base64;
use Passwd::Keyring::Auto;
use IO::Pty;
use Net::SFTP::Foreign;

my $server = 'submissions.dcc.icgc.org';
my $wsurl = "https://$server/ws";
my $app = 'ICGC-DCC-SFTP';
my $group = 'ICGC-DCC';
my $realm = $server;

my $user;
my $pass;
my $reset;
my $format;
my $mode;
my $opts;
my $debug;
my $dryrun;
my $drysftp;

GetOptions(
    'user|u=s'          =>  \$user,
    'pass|p=s'          =>  \$pass,
    'reset|r!'          =>  \$reset, ## reset pass
    'mode|m=s'          =>  \$mode,
    'opts|v=s%'         =>  \$opts,
    'format|f=s'        =>  \$format, ## output format
    'debug!'            =>  \$debug,
    'dry-run!'          =>  \$dryrun,
    'dry-run-sftp!'     =>  \$drysftp,
);

## for now only 'txt' or 'json'
$format ||= 'txt';

## handlers for mode flag
my $modes = {
    'list-projects'     =>  \&do_list_projects,
    'list-dirs'         =>  \&do_list_dirs,
    'list-dir-contents' =>  \&do_list_dir_contents,
    'upload-dir'        =>  \&do_upload_dir,
    'validate'          =>  \&do_validate,
};

## fetch user password from keychain
($user, $pass) = do_auth($user, $pass);
 
## execute modes
if (defined($modes->{$mode})) {
    $modes->{$mode}($opts);
} else {
    croak("Unsupported mode '$mode', supported modes are:\n".join("\n", sort keys %{$modes})."\n");
}

sub do_list_projects {
    my ($opts) = @_;
    my $projects = get_project_names();

    if ($format eq 'json') {
        print to_json($projects);
    } elsif ($format eq 'txt') {
        foreach my $key(sort keys %{$projects}) {
            print join("\t", ($key, $projects->{$key}))."\n";
        } 
    }
}

sub do_list_dirs {
    my ($opts) = @_;
    my $dirs = get_project_dirs();

    if ($format eq 'json') {
        print to_json($dirs);
    } elsif ($format eq 'txt') {
        foreach my $dir(sort keys %{$dirs}) {
            print join("\t", ($dir))."\n";
        } 
    }
}

sub do_list_dir_contents {
    my ($opts) = @_;

    if (! defined($opts->{'project-key'})) {
        confess("Validate mode requires value for 'project-key' with --opts flag");
    }
    my $project_key = $opts->{'project-key'};

    my $files = get_project_files($project_key);
    
    if ($format eq 'json') {
        print to_json($files);
    } elsif ($format eq 'txt') {
        foreach my $filename(sort keys %{$files}) {
            print $files->{$filename}->{'ll'}."\n";
        } 
    }
}


sub get_projects {
    ## get projects list from REST API
    my $projects = decode_json(get_json('/projects'));

    return $projects;
}

sub get_project_names {
    my $projects = get_projects();
    ## set up project key => name hash
    my $project_names = {};
    foreach my $project(@{$projects}) {
        $project_names->{$project->{'key'}} = $project->{'name'};
    }
    return $project_names;
}

sub get_project_dirs {
    ## get SFTP project directories list

    if ($dryrun) {
        return {};
    }

    my $sftp = get_sftp($user, $pass);
    my $dirs = $sftp->ls()
        or croak("Failed to list project dirs ".$sftp->error);
    my $project_dirs = {};
    foreach my $dir(@{$dirs}) {
        $project_dirs->{$dir->{'filename'}} = 1;
    }

    return $project_dirs;
}

sub get_project_files {
    my ($project_key) = @_;
    ## get SFTP project directories list

    if ($dryrun) {
        return {};
    }

    my $sftp = get_sftp($user, $pass);
    
    $sftp->setcwd($project_key)
        or croak("Failed to set working dir to '$project_key': ".$sftp->error);

    my $project_files = $sftp->ls()
        or croak("Failed to list dir '$project_key': ".$sftp->error);

    my $files = {};
    foreach my $file(@{$project_files}) {
        my $dt = DateTime->from_epoch('epoch' => $file->{'a'}->{'mtime'});
        my $timestamp = $dt->ymd().' '.$dt->hms();
        $files->{$file->{'filename'}} = {
            'timestamp' =>  $timestamp,
            'atime' =>  $file->{'a'}->{'atime'},
            'mtime' =>  $file->{'a'}->{'mtime'},
            'size'  =>  $file->{'a'}->{'mtime'},
            'll'    =>  $file->{'longname'},
        };
    }

    return $files;
}
sub get_json {
    my ($resource) = @_;

    unless ($resource =~ /^\//) {
        confess("Bad call to get_json");
    }

    my $response = rest_get($wsurl.$resource);

    my $json = undef;
    if ($response->{'code'} == 200) {
        $json = $response->{'content'};
    } elsif ($response->{'code'} == 401) {
        unset_pass($user);
        croak("Server responded with '401 Unauthorized', user password removed from keychain");  
    } else {
        croak('Received unhandled response code '.$response->{'code'}.' from server');
    }

    return $json;
}

sub unset_pass {
    my ($user) = @_;

    my $keyring = get_keyring(app => $app, group => $group);
    $keyring->clear_password($user, $realm);
}

sub do_auth {
    my ($user, $pass) = @_;

    if (! defined($user)) {
        croak("Must supply a web user with --user");
    }
    my $keyring = get_keyring(app => $app, group => $group);
    my $p = $keyring->get_password($user, $realm);
    if (! $p) {
        if (! defined($pass)) {
            croak("Must supply a web user password with --pass");
        } else {
            $keyring->set_password($user, $pass, $realm);
        }
    } else {
        if ($p ne $pass) {
            if ($reset) {
                $keyring->set_password($user, $pass, $realm);
            } else {
                croak("Password supplied with --pass did not match keychain, add --reset flag to set new password");
            }
        }
    }

    return ($user, $pass);
}

sub get_user_agent {
    
    my $auth         = 'X-DCC-Auth '.encode_base64("$user:$pass");
    my $content_type = 'application/json';
    my $accept       = 'application/json';
  
    my $ua = LWP::UserAgent->new();

    $ua->default_header('Authorization' => $auth);
    $ua->default_header('Content-Type'  => $accept);
    $ua->default_header('Accept'        => $content_type);

    return $ua;
}

sub rest_get {
    my ($url) = @_;
    
    if ($debug) {
        print "GET $url\n";
    }
    
    if ($dryrun) {
        return {'content' =>  '[]', 'code'  =>  200};
    }

    my $ua = get_user_agent();

    {
        my $content = '';
        my $response = $ua->get($url, ':content_cb', sub { my ($data) = @_; $content .= $data; });

        return {'content' => $content, 'code' => $response->code()};
    }
}

sub rest_post {
    my ($url, $json) = @_;
    
    if ($debug) {
        print "POST $url\n";
        print "Body: $json\n";
    }

    if ($dryrun) {
        return {'content' =>  '[]', 'code'  =>  200};
    }

    my $request = get_post_request($url, $json);

    my $ua = LWP::UserAgent->new;

    {
        my $content = '';
        my $response = $ua->request($request, ':content_cb', sub { my ($data) = @_; $content .= $data; });

        return {'content' => $content, 'code' => $response->code()};
    }
}

sub get_post_request {
    my ($url, $json) = @_;

    my $auth         = 'X-DCC-Auth '.encode_base64("$user:$pass");
    my $content_type = 'application/json';
    my $accept       = 'application/json';
  
    my $req = HTTP::Request->new( 'POST', $url );

    $req->header('Authorization' => $auth);
    $req->header('Content-Type'  => $accept);
    $req->header('Accept'        => $content_type);
    
    $req->content( $json );

    return $req;
}

sub do_validate {
    my ($opts) = @_;

    if (! defined($opts->{'emails'})) {
        confess("Validate mode requires value for 'emails' with --opts flag");
    }
    my $emails = [split(/,/, $opts->{'emails'})];
    
    if (! defined($opts->{'project-key'})) {
        confess("Validate mode requires value for 'project-key' with --opts flag");
    }
    my $key = $opts->{'project-key'};

    return do_validate_rest($key, $emails);
}

sub get_validate_rest_json {
    my ($project, $email_arr_ref) = @_; 

    my $post_data = [
        {
            'key'       =>  $project,
            'emails'    =>  $email_arr_ref
        }
    ];

    my $json = to_json($post_data);

    return $json;
}


sub do_validate_rest {
    my ($project, $email_arr_ref) = @_;

    my $resource = '/nextRelease/queue';

    my $json = get_validate_rest_json($project, $email_arr_ref);

    my $response = rest_post($wsurl.$resource, $json); 

    if ($response->{'code'} == 200) {
        $json = decode_json($response->{'content'});
        return $json;
    } elsif ($response->{'code'} == 401) {
        unset_pass($user);
        croak("Server responded with '401 Unauthorized', user password removed from keychain");  
    } else {
        croak('Received unhandled response code '.$response->{'code'}.' from server');
    }

    return undef;
}

sub get_sftp {
    my ($user, $pass) = @_;

    my %params = (
        'host' => $server, 
        'user' => $user, 
        'password' => $pass,  
    );
    if ($debug) {
        $params{'more'} = '-v';
    }

    my $sftp = Net::SFTP::Foreign->new(%params);

    $sftp->die_on_error("Error executing an SFTP step");

    return $sftp;
}

sub do_upload_dir {
    my ($opts) = @_;

    if (! defined($opts->{'project-key'})) {
        confess("Validate mode requires value for 'project-key' with --opts flag");
    }
    if (! defined($opts->{'input-dir'})) {
        confess("Validate mode requires value for 'input-dir' with --opts flag");
    }
    my $input_dir;
    if (-d $opts->{'input-dir'}) {
        $input_dir = abs_path($opts->{'input-dir'}); 
    }

    my $project_key = $opts->{'project-key'};
    my $projects = get_project_names();

    if (! defined($projects->{$project_key})) {
        confess("Unrecognized project key provided as 'project-key' value");
    }

    my $sftp = get_sftp($user, $pass);
    
    ## replace-all option removes all existing files
    if (defined($opts->{'replace-all'})) {
        my $files = $sftp->ls('/'.$project_key);

        foreach my $file(@{$files}) {
            if ($debug) {
                print "Removing '/$project_key/$file->{filename}'\n";
            }
            unless ($drysftp) {
                $sftp->remove('/'.$project_key.'/'.$file->{'filename'});
            }
        }
    }

    ## do mput into project dir
    unless ($drysftp) {
        $sftp->mput($input_dir.'/*', '/'.$project_key.'/', (
            'best_effort' => 1,     ## ignore minor errors
            'resume' => 'auto',     ## resume if newer than local
        ));
    } 
}
