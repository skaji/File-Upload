use File::Spec;
use File::Basename qw(dirname);
use constant DAY => 60 * 60 * 24;
my $basedir = File::Spec->rel2abs(File::Spec->catdir(dirname(__FILE__), '..'));
+{
    root => "$basedir/root",
    root_maxage => 2  * DAY,
    log_maxage  => 30 * DAY,
};
