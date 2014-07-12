package File::Upload::AtomicChange;
use strict;
use warnings;
use File::Temp 'tempfile';
use Fcntl qw(:DEFAULT :flock);

use Exporter 'import';
our @EXPORT_OK = qw(FILENAME_ERROR INTENAL_ERROR FLOCK_ERROR CONTENT_LENGTH_ERROR);
our %EXPORT_TAGS = (error_constant => \@EXPORT_OK);
use constant FILENAME_ERROR       => 1;
use constant INTERNAL_ERROR       => 2;
use constant FLOCK_ERROR          => 3;
use constant CONTENT_LENGTH_ERROR => 4;

sub new {
    my ($class, $root, $filename, $length) = @_;
    my $self = bless {
        error => 0,
        root => $root,
        filename => $filename,
        length => $length
    }, $class;
    unless ($self->is_valid_filename) {
        $self->{error} = FILENAME_ERROR;
        return $self;
    }
    my $lockfile = "$root/.temp/$filename.lock";
    sysopen my $lockfh, $lockfile, O_CREAT | O_RDWR, 0666
        or do {
            warn "sysopen $lockfile: $!";
            $self->{error} = INTERNAL_ERROR;
            return $self;
        };
    flock $lockfh, LOCK_EX | LOCK_NB
        or do {
            warn "flock $lockfile: $!";
            $self->{error} = FLOCK_ERROR;
            return $self;
        };
    my ($tempfh, $tempfile) = tempfile "$root/.temp/$filename.temp.XXXXX", UNLINK => 0;
    chmod 0644, $tempfile;
    $self->{lockfh}   = $lockfh;
    $self->{lockfile} = $lockfile;
    $self->{tempfh}   = $tempfh;
    $self->{tempfile} = $tempfile;
    $self;
}
sub error { shift->{error} }

sub print : method {
    my ($self, $byte) = @_;
    my $fh = $self->{tempfh}
        or die "already closed $self->{tempfile}";
    CORE::print {$fh} $byte;
}

sub close {
    my $self = shift;
    CORE::close $self->{tempfh};
    undef $self->{tempfh};
    if (defined $self->{length}) {
        my $tempfile_length = -s $self->{tempfile};
        if ($tempfile_length != $self->{length}) {
            warn sprintf "content length mismatch: expected=%d, actual=%d\n",
                $self->{length}, $tempfile_length;
            $self->{error} = CONTENT_LENGTH_ERROR;
            return;
        }
    }

    rename $self->{tempfile}, "$self->{root}/$self->{filename}"
        or do {
            warn "rename $self->{tempfile}, $self->{root}/$self->{filename} failed: $!";
            $self->{error} = INTERNAL_ERROR;
            return;
        };
    return 1;
}

sub is_valid_filename {
    my $self = shift;
    my $filename = shift || $self->{filename} || "";
    return $filename =~ /^[a-zA-Z0-9_-][a-zA-Z0-9._-]*$/ ? 1 : 0;
}

sub DESTROY {
    my $self = shift;
    my $tempfile = $self->{tempfile};
    if ($tempfile && -f $tempfile) {
        warn "unexpectedly $tempfile exists, unlink it";
        unlink $tempfile;
    }
    CORE::close $self->{tempfh}    if $self->{tempfh};
    unlink $self->{lockfile}       if $self->{lockfile};
    flock $self->{lockfh}, LOCK_UN if $self->{lockfh};
    CORE::close $self->{lockfh}    if $self->{lockfh};
}


1;
