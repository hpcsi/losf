#!/usr/bin/env perl

#use Test::More;
use Test::More tests => 21;
#use Test::Files;
use File::Basename;
use File::Temp qw(tempfile);
use Cwd 'abs_path';
use LosF_test_utils;


print "---------------------\n";
print "LosF Regression Tests\n";
print "---------------------\n";

my $losf_dir=dirname(dirname(abs_path($0)));
my $redirect = "1> /dev/null";
#my $redirect="";

#------------------------------------------------------

print "\nChecking install manifest:\n";

@BINS=("losf","update","node_types","koomie_cf",
       "initconfig","sync_config_files","update_hosts");

foreach $bin (@BINS) {
    test_binary_existence("$losf_dir/$bin");
}

#------------------------------------------------------

print "\nInitializing test config ";
my $tmpdir = File::Temp->newdir(DIR=>$dir, CLEANUP => 1) || die("Unable to create temporary directory");
print "--> tmpdir = $tmpdir\n";

$ENV{'LOSF_CONFIG_DIR'} = "$tmpdir";

ok(system("$losf_dir/initconfig test $redirect") == 0,"initconfig runs");

#subtest 'Verify initconfig' => sub {
#    plan tests => 6;

ok(-s "$tmpdir/config.machines","config.machines exists");
ok(-s "$tmpdir/config.test","config.test exists");
ok(-s "$tmpdir/ips.test","ips.test exists");
ok(-d "$tmpdir/const_files/test/master","const_files/test/master exists");
ok(-s "$tmpdir/os-packages/test/packages.config","os-packages/test/packages.config exists");
ok(-s "$tmpdir/custom-packages/test/packages.config","custom-packages/test/packages.config exists");
#};

ok(system("$losf_dir/node_types $redirect") == 0,"node_types runs");
ok(system("$losf_dir/update -q 1> $tmpdir/.result" ) == 0,"update runs");

my $igot=(`cat $tmpdir/.result`); 
chomp($igot);			# remove newline
$igot =~ s/\e\[\d+m//g;		# remove any colors

my $expect = "OK: [RPMs: OS 0/0  Custom 0/0] [Files: 0/0] [Links: 0/0] [Services: 0/0] [Perms: 0/0] -> master";

ok("$igot" eq "$expect","update output ok");
ok(system("$losf_dir/rpm_topdir -q 1> $tmpdir/.result" ) == 0,"rpm_topdir runs");

open(IN,"<$tmpdir/.result")     || die "Cannot open $tmpdir/.result\n";

$line = <IN>; chomp($line);
ok($line =~ m/^\[LosF\] Node type:       test -> master$/,"rpm_topdir -> correct node type");

$line = <IN>; chomp($line);
ok($line =~ m/^\[LosF\] Config dir:      $tmpdir$/,"rpm_topdir -> correct config dir");

$line = <IN>; chomp($line);
ok($line =~ m/^\[LosF\] RPM topdir:      $tmpdir\/test\/rpms$/,"rpm_topdir -> correct RPM topdir ");

close(IN);

done_testing();

