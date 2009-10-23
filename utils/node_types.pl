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

package node_types;
use strict;
use OSF_paths;

use lib "$osf_log4perl_dir";
use lib "$osf_ini4perl_dir";
use lib "$osf_utils_dir/";

use base 'Exporter';

require "$osf_utils_dir/utils.pl";
require "$osf_utils_dir/parse.pl";
require "$osf_utils_dir/header.pl";

# Global Variables

my @clusters;			# cluster names/definitions
my $num_clusters;		# number of clusters to be managed
my $host_name;			# local running hostname
my $domain_name;		# local domainname
my $global_cfg;			# global input configuration
my $node_cluster;		# cluster ownership for local host
my $node_type;			# node type for local host

# Exported Variable

our @EXPORT = qw($node_cluster $node_type);

#---------------
# Initialization
#---------------

#init_logger();
verify_sw_dependencies();
print_header();


#INFO("\n-----------------------------\n");
INFO("--> Mode = Node Type Determination   \n");
INFO("-"x 50 ."\n");
#INFO("-----------------------------\n");

chomp($host_name=`hostname -s`);
chomp($domain_name=`dnsdomainname`);

#---------------
# Global Parsing
#---------------

init_config_file_parsing("$osf_utils_dir/config.machines");
(our $node_cluster, our $node_type) = query_global_config_host($host_name,$domain_name);

# All Done.




