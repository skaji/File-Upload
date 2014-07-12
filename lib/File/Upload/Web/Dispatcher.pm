package File::Upload::Web::Dispatcher;
use strict;
use warnings;
use utf8;
use Amon2::Web::Dispatcher::RouterBoom;
use File::Upload::AtomicChange ':error_constant';
use File::pushd 'pushd';
use constant CHUNK_SIZE => 64 * 1024;

get '/' => sub {
    my ($c) = @_;
    my $format = $c->req->query_parameters->{format} || "";
    my @files;
    {
        my $gurard = pushd $c->config->{root};
        for my $file (sort grep -f, glob "*") {
            my @stat = stat $file;
            my $size  = $stat[7];
            my $mtime = $stat[9];
            push @files, { name => $file, mtime => $mtime, size => $size };
        }
    }
    if ($format eq "json") {
        return $c->render_json( \@files );
    } else {
        return $c->render('index.tx', {
            files => \@files,
        });
    }
};

any '/upload/:filename' => sub {
    my ($c, $argv) = @_;
    if ($c->req->method ne 'PUT') {
        return $c->render_text( 405 => "405 Only PUT method allowed\n");
    }
    my $filename = $argv->{filename};
    my $content_length = $c->req->content_length;
    if (!$content_length) {
        return $c->render_text( 411 => "411 Length Required\n" );
    }
    my $fh = File::Upload::AtomicChange->new(
        $c->config->{root}, $filename, $content_length
    );
    if (my $e = $fh->error) {
        if ($e == FILENAME_ERROR) {
            return $c->render_text( 400 => "400 Filename '$filename' is invalid\n" );
        } elsif ($e == FLOCK_ERROR) {
            return $c->render_text( 503 => "503 Other uploding $filename in progress\n" );
        } else {
            return $c->render_text( 500 => "500 Internal Server Error\n" );
        }
    }
    my $input = $c->req->input;
    my $offset = 0;
    while (1) {
        my $len = read $input, my $buf, CHUNK_SIZE, $offset;
        if (!defined $len) {
            warn "read request body failed: $!";
            return $c->render_text( 500 => "500 Internal Server Error\n" );
        } elsif ($len == 0) {
            last;
        } else {
            $fh->print($buf);
            $offset += $len;
        }
    }
    my $ok = $fh->close;
    if (!$ok) {
        if ($fh->error == CONTENT_LENGTH_ERROR) {
            return $c->render_text( 500 => "500 Content length mismatch\n" );
        } else {
            return $c->render_text( 500 => "500 Internal Server Error\n" );
        }
    }
    $c->render_text( 200 => "200 Successfully uploaded $filename\n" );
};

get '/download/:filename' => sub {
    my ($c, $argv) = @_;
    my $filename = $argv->{filename};
    File::Upload::AtomicChange->is_valid_filename($filename)
        or return $c->render_text( 400 => "400 Filename '$filename' is invalid\n" );
    my $abs_filename = $c->config->{root} . "/$filename";
    -f $abs_filename
        or return $c->render_text( 404 => "404 '$filename' is not found\n" );
    open my $fh, "<", $abs_filename or do {
        warn "open '$abs_filename': $!";
        return $c->render_text( 500 => "500 Internal Server Error\n" );
    };
    my $length = -s $abs_filename or do {
        warn "-s '$abs_filename': $!";
        return $c->render_text( 500 => "500 Internal Server Error\n" );
    };

    my $res = $c->create_response(200);
    $res->body($fh);
    $res->content_type('application/octet-stream');
    $res->content_length( $length );
    $res->header( 'Content-Disposition' => qq[attachment; filename="$filename"] );
    return $res;
};


1;
