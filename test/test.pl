#!/usr/bin/env perl
#-----------------------------------------------------------------------bl-
#--------------------------------------------------------------------------
# 
# LosF - a Linux operating system Framework for HPC clusters
#
# Copyright (C) 2007-2014 Karl W. Schulz <losf@koomie.com>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the Version 2 GNU General
# Public License as published by the Free Software Foundation.
#
# These programs are distributed in the hope that they will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc. 51 Franklin Street, Fifth Floor, 
# Boston, MA  02110-1301  USA
#
#-----------------------------------------------------------------------el-
# LosF Regression testing driver.
#--------------------------------------------------------------------------

use strict;

use Test::More;
use Test::More tests => 30;
use File::Basename;
use File::Temp qw(tempfile);
use File::Compare;
use Cwd 'abs_path';
use LosF_test_utils;
use Sys::Hostname;

print "---------------------\n";
print "LosF Regression Tests\n";
print "---------------------\n";

my $losf_dir=dirname(dirname(abs_path($0)));
my $redirect = "1> /dev/null";
#my $redirect="";

# local hostname

my @hostTmp     = split(/\./,hostname);
my $hostname    = shift(@hostTmp);

#------------------------------------------------------

print "\nChecking install manifest:\n";

my @BINS=("losf","update","node_types","koomie_cf",
       "initconfig","sync_config_files","update_hosts");

foreach my $bin (@BINS) {
    test_binary_existence("$losf_dir/$bin");
}

#------------------------------------------------------
print "\nChecking versioning consistency:\n";
my $config_ac="$losf_dir/configure.ac";

ok(-s "$losf_dir/VERSION","version file present");
ok(-s "$losf_dir/configure.ac","configure.ac file present");

my $loc_version=`cat $losf_dir/VERSION`; chomp($loc_version);

open(IN,"$losf_dir/configure.ac") || die "Cannot open configure.ac\n";
ok ( (grep{/\[$loc_version\]/} <IN>) ,"version file matches configure.ac");
close(IN);

my $version_update=`$losf_dir/update -v | grep Version`;
ok ($version_update == "LosF: Version $loc_version","\"update -v\" matches manifest");

my $version_losf=`$losf_dir/losf -v | grep Version`;
ok ($version_update == "LosF: Version $loc_version","\"losf -v\" matches manifest");

my $version_losf=`$losf_dir/losf --version | grep Version`;
ok ($version_update == "LosF: Version $loc_version","\"losf --version\" matches manifest");

#------------------------------------------------------

print "\nInitializing test config ";
my $tmpdir = File::Temp::tempdir(CLEANUP => 1) || die("Unable to create temporary directory");
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


# node_type tests
ok(system("$losf_dir/node_types 1> $tmpdir/.result" ) == 0,"node_types runs");

my $igot=(`cat $tmpdir/.result`); 

my $ref_output = <<"END_OUTPUT";
[LosF] Node type:       test -> master
[LosF] Config dir:      $tmpdir
END_OUTPUT

ok("$igot" eq "$ref_output","node_type output ok");

# node_type with argument tests
ok(system("$losf_dir/node_types master 1> $tmpdir/.result" ) == 0,"node_types (w/ argument) runs");

$igot=(`cat $tmpdir/.result`); 
chomp($igot); 

ok("$igot" eq $hostname,"node_type (w/ argument) output ok");

# update tests

ok(system("$losf_dir/update -q  1> $tmpdir/.result" ) == 0,"update runs");

$igot=(`cat $tmpdir/.result`); 
chomp($igot);			# remove newline
$igot =~ s/\e\[\d+m//g;		# remove any colors

my $expect = "OK: [RPMs: OS     0/0  Custom     0/0] [Files:    0/0] [Links:   0/0] [Services:   0/0] [Perms:   0/0] -> master";

ok("$igot" eq "$expect","update output ok");
ok(system("$losf_dir/rpm_topdir -q 1> $tmpdir/.result" ) == 0,"rpm_topdir runs");

open(IN,"<$tmpdir/.result")     || die "Cannot open $tmpdir/.result\n";

my $line = <IN>; chomp($line);
ok($line =~ m/^\[LosF\] Node type:       test -> master$/,"rpm_topdir -> correct node type");

$line = <IN>; chomp($line);
ok($line =~ m/^\[LosF\] Config dir:      $tmpdir$/,"rpm_topdir -> correct config dir");

$line = <IN>; chomp($line);
ok($line =~ m/^\[LosF\] RPM topdir:      $tmpdir\/test\/rpms$/,"rpm_topdir -> correct RPM topdir ");

close(IN);

done_testing();


