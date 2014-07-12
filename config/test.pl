use File::Spec;
use File::Basename qw(dirname);
my $basedir = File::Spec->rel2abs(File::Spec->catdir(dirname(__FILE__), '..'));
+{
    root => "$basedir/t/root",
    maxage => 60 * 60 * 24 * 2, # 2days
};
