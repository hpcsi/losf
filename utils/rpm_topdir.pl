#!/usr/bin/perl
#
#-------------------------------------------------------------------
#
# Utility to read a cluster's top-level rpm build directory from
# global config file.
#
# $Id: node_types.sh 151 2009-10-20 02:44:48Z karl $
#-------------------------------------------------------------------

use strict;
use OSF_paths;
use node_types;

use lib "$osf_log4perl_dir";
use lib "$osf_ini4perl_dir";
use lib "$osf_utils_dir/";

require "$osf_utils_dir/utils.pl";
require "$osf_utils_dir/parse.pl";
require "$osf_utils_dir/header.pl";

#---------------
# Initialization
#---------------


my $logr = get_logger();

verify_sw_dependencies(); $logr->level($ERROR);
print_header();

#---------------------
# Determine node type
#---------------------

chomp(my $host_name=`hostname -s`);


(my $node_cluster, my $node_type) = determine_node_membership();

#---------------------------
# Determine Local RPM TopDir
#---------------------------

(my $rpm_topdir) = query_cluster_rpm_dir($node_cluster);

$logr->level($INFO);
INFO("\nRPM_TOPDIR = $rpm_topdir\n");
