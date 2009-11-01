#!/usr/bin/perl
#
# $Id$
#
#-----------------------------------------------------------------------
# Utility for installing previously downloading OS updates
# from a centralized mirror/repository.
# 
# Originally: 4-15-2007 - ks
#
# Questions/Problems?: karl@tacc.utexas.edu
# Texas Advanced Computing Center
#-----------------------------------------------------------------------

use strict;
use OSF_paths;
use node_types;

use lib "$osf_log4perl_dir";
use lib "$osf_ini4perl_dir";
use lib "$osf_utils_dir/";

require "$osf_utils_dir/utils.pl";
require "$osf_utils_dir/parse.pl";
require "$osf_utils_dir/header.pl";

my $DEBUG_MODE=0;      # 1=no pkgs installed

#---------------
# Initialization
#---------------

verify_sw_dependencies();

print_header();
INFO("--> Mode = Install OS Updates   \n");
INFO("-"x 50 ."\n");

#---------------------
# Determine node type
#---------------------

chomp(my $host_name=`hostname -s`);

(my $node_cluster, my $node_type) = determine_node_membership();

#---------------------------------
# Determine read location for rpms
#---------------------------------

my $prod_date = query_global_config_os_sync_date($node_cluster,$node_type);
my $RPMDIR="$osf_osupdates_dir/$node_cluster/$node_type/$prod_date";

DEBUG("--> RPMDIR=$RPMDIR\n");
INFO ("--> Desired production date = $prod_date\n");

if ( ! -d $RPMDIR ) {
    MYERROR("Unable to find rpm directory for the desired production date!",
	    "Please be sure to run download_updates first and update your",
	    "global configuration file accordingly with the desired production",
	    "settings.");
}

INFO("--> Installing downloaded os-update rpms from:\n");
INFO("    $RPMDIR\n");

#-------------------
# Already installed?
#-------------------

INFO("--> Checking if desired rpms are already installed...\n");

my $not_updated   = 0;
my $not_installed = 0;
my @missing_rpms;

opendir(DIR,"$RPMDIR");
my @tmp_pkgs = grep(/\.rpm$/,readdir(DIR));
my $avail_pkgs = @tmp_pkgs;
closedir(DIR);

# Strip .rpm from file name

my @pkgs;

foreach my $loc_rpm  (@tmp_pkgs) {
    push(@pkgs,substr($loc_rpm,0,-4));
}

INFO("    --> Total number of available packages = $avail_pkgs\n");

foreach my $loc_rpm  (@pkgs) {
    DEBUG("   --> rpm =  $loc_rpm\n");
    chomp(my $result = `rpm -q $loc_rpm 2>&1`);
    DEBUG("   --> result = $result\n");

    if ($result =~ m/\Q$loc_rpm\E is not installed/ ) {
 	DEBUG("   --> $loc_rpm not installed - adding to final list\n");
 	push(@missing_rpms,$loc_rpm);
	$not_installed++;
	$not_updated=1;
    }
}

my $prev_installed = $avail_pkgs - $not_installed;

INFO("    --> $prev_installed of $avail_pkgs packages have been previously installed\n");

if ( $not_updated == 0) {
    print "\n** $host_name is up to date with OS downloads...\n\n";
    exit(0);
} 

#------------------
# Verify the rpms
#------------------

INFO("--> Verifying rpm dependencies...\n");

chomp(my $VERIFY=`rpm -U --ignoresize --test $RPMDIR/*.rpm 2>&1`);
chomp(my $PARTIAL_INSTALL=`echo $VERIFY | grep -v "is already installed"`);

my $RPM_EXTRA_OPTION="";
my $INCREMENTAL=0;

if ( length($VERIFY) == 0 ) {
    INFO("    --> Dependencies verified; proceeding with installation...\n");
    INFO("\n");
} elsif ( length($PARTIAL_INSTALL) == 0 ) {
    INFO("\n");
    INFO("Note: Partial install detected; it looks like a previous attempt\n");
    INFO("to install package updates was only partially successful.\n");
    INFO("\n");
    INFO("Picking up from previous install....\n");
    $INCREMENTAL=1;
    $RPM_EXTRA_OPTION="--replacepkgs";
} else {
    MYERROR("\n","rpm dependencies not verified; this may mean that the",
	    "host node which downloaded the os updates differes from the",
	    "current installation target","\n",
	    "$VERIFY","partial = $PARTIAL_INSTALL");
}

#---------------------
# Install the packages
#---------------------

my @final_rpm_list;

foreach my $loc_rpm  (@pkgs) {
    push(@final_rpm_list,"$RPMDIR/$loc_rpm.rpm");
}

my $cmd = "rpm -Uvh --ignoresize $RPM_EXTRA_OPTION @final_rpm_list\n";

if ($DEBUG_MODE == 1) {
    INFO("--> Debug Mode: skipping rpm installs\n");
} else {
    DEBUG("cmd = $cmd\n");    
    `$cmd`
}

INFO("\nUpgrade Compete\n");




