#!/usr/bin/perl
#
# $Id: node_types.sh 151 2009-10-20 02:44:48Z karl $
#
#-----------------------------------------------------------------------
# Routines for determining cluster node types and software production
# dates for any general OS revisions.  Definitions are based on inputs
# provided in global configuration file
# 
# See config.global for input variables.

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
use lib './dependencies/mschilli-log4perl-d124229/lib';
use lib './dependencies/Config-IniFiles-2.52/lib';

# Global Variables

my @Clusters;			# Cluster names/definitions
my $num_clusters;		# Number of clusters to be managed
my $host_name;			# Local running hostname
my $global_cfg;			# Global input configuration
my $node_cluster;		# Cluster ownership for local host
my $node_type;			# Node type for local host

require 'utils.pl';
require 'parse.pl';

#---------------
# Initialization
#---------------

verify_sw_dependencies();

my $logr = get_logger();

INFO("\n-----------------------------\n");
INFO("   Node Type Determination   \n");
INFO("-----------------------------\n");

chomp($host_name=`hostname -f`);

#---------------
# Global Parsing
#---------------

init_config_file_parsing("config.machines");
query_global_config_host($host_name);

# All Done.




