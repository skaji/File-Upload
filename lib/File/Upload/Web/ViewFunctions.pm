package File::Upload::Web::ViewFunctions;
use strict;
use warnings;
use utf8;
use parent qw(Exporter);
use Module::Functions;
use File::Spec;
use POSIX ();
use Number::Bytes::Human ();
use Time::Duration ();

sub ago {
    my $sec = shift || 0;
    Time::Duration::ago( time - $sec );
}
sub format_bytes {
    Number::Bytes::Human::format_bytes(@_);
}
sub format_date {
    my $time = shift || time;
    POSIX::strftime("%F %T", localtime($time));
}



our @EXPORT = get_public_functions();

sub commify {
    local $_  = shift;
    1 while s/((?:\A|[^.0-9])[-+]?\d+)(\d{3})/$1,$2/s;
    return $_;
}

sub c { File::Upload->context() }
sub uri_with { File::Upload->context()->req->uri_with(@_) }
sub uri_for { File::Upload->context()->uri_for(@_) }
sub abs_uri_for {
    my $c   = File::Upload->context;
    sprintf '%s://%s%s',
        $c->req->scheme, $c->req->env->{HTTP_HOST}, $c->uri_for(@_);
}

{
    my %static_file_cache;
    sub static_file {
        my $fname = shift;
        my $c = File::Upload->context;
        if (not exists $static_file_cache{$fname}) {
            my $fullpath = File::Spec->catfile($c->base_dir(), $fname);
            $static_file_cache{$fname} = (stat $fullpath)[9];
        }
        return $c->uri_for(
            $fname, {
                't' => $static_file_cache{$fname} || 0
            }
        );
    }
}

1;
