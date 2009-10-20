#!/usr/bin/perl
#
# $Id: node_types.sh 151 2009-10-20 02:44:48Z karl $
#
#-----------------------------------------------------------------------
# Routines for determining cluster node types and software production
# dates for any general OS revisions.  Definitions are based on inputs
# provided in global configuration file(s).
# 
# See config.global for top-level input variables.

# Typical node types for an HPC cluster are:
#
# master, login, Lustre oss/mds, and compute.
# 
# Syntax for the designation is "node_type:hostname". For convenience, 
# the hostname designation can be replaced by a regular expression.
#
# Originally: 04-15-2007 -> Lonestar3 version
#             06-21-2007 -> Ranger    version
#             10-19-2009 -> Longhorn2 version (with more generality)
#
# Questions/Problems?: karl@tacc.utexas.edu
# Texas Advanced Computing Center 
#-----------------------------------------------------------------------

use strict;
use lib '/home/build/admin/hpc_stack/utils/dependencies/mschilli-log4perl-d124229/lib';
use lib '/home/build/admin/hpc_stack/utils/dependencies/Config-IniFiles-2.52/lib';

# Global Variables

my @Clusters;			# Cluster names/definitions
my $num_clusters;		# Number of clusters to be managed
my $host_name;			# Local running hostname
my $domain_name;		# Local domainname
my $global_cfg;			# Global input configuration
my $node_cluster;		# Cluster ownership for local host
my $node_type;			# Node type for local host

my $top_dir="/home/build/admin/hpc_stack";

require "$top_dir/utils/utils.pl";
require "$top_dir/utils/parse.pl";

#---------------
# Initialization
#---------------

verify_sw_dependencies();

INFO("\n-----------------------------\n");
INFO("   Node Type Determination   \n");
INFO("-----------------------------\n");

chomp($host_name=`hostname -s`);
chomp($domain_name=`dnsdomainname`);

#---------------
# Global Parsing
#---------------

init_config_file_parsing("$top_dir/utils/config.machines");
query_global_config_host($host_name,$domain_name);

# All Done.




