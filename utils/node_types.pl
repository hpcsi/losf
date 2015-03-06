#!/usr/bin/env perl
#-----------------------------------------------------------------------bl-
#--------------------------------------------------------------------------
# 
# LosF - a Linux operating system Framework for HPC clusters
#
# Copyright (C) 2007-2015 Karl W. Schulz <losf@koomie.com>
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
# Determine cluster/node membership based on LosF runtime config
#--------------------------------------------------------------------------

use strict;
use LosF_paths;
use LosF_utils;

use lib "$losf_utils_dir/";
use base 'Exporter';

require "$losf_utils_dir/parse.pl";

my $output_mode = $ENV{'LOSF_LOG_MODE'};
my $standalone  = $ENV{'LOSF_STANDALONE_UTIL'};

determine_node_membership(@ARGV);

BEGIN {
    my $osf_membership_init = 0;        # initialization flag 
    my $node_cluster;		        # cluster ownership for local host
    my $node_type;			# node type for local host

    sub determine_node_membership {

	# Global Variables

	my @clusters;			# cluster names/definitions
	my $num_clusters;		# number of clusters to be managed
	my $host_name;			# local running hostname
	my $domain_name;		# local domainname
	my $global_cfg;			# global input configuration

	verify_sw_dependencies();
	my $logr = get_logger();

	if ( "$output_mode" eq "INFO"  || 
	     "$output_mode" eq "ERROR" ||
	     "$output_mode" eq "WARN"  ||
	     "$output_mode" eq "DEBUG" ) {
	    $logr->level($output_mode);
	} else {
	    $logr->level($INFO);
	}

	if ( $osf_membership_init == 1 ) {
	    return($node_cluster,$node_type);
	}

        #---------------
        # Initialization
        #---------------

	DEBUG("** LosF Node Type Determination:\n");

	chomp($host_name=`hostname -s`);
	chomp($domain_name=`dnsdomainname 2> /dev/null`);

        #---------------
        # Global Parsing
        #---------------
	
	init_config_file_parsing("$losf_config_dir/config.machines");
	($node_cluster, $node_type) = query_global_config_host($host_name,$domain_name);

	# Check for custom config_dir - environment variable takes precedence

	if ( defined $ENV{'LOSF_CONFIG_DIR'} ) {
	    DEBUG("    --> LOSF_CONFIG_DIR setting takes precedence - skipping custom config check\n");
	} else {
	    my $dir = query_cluster_local_config_dir($node_cluster,$node_type,$host_name);
	    if ( "$dir" ne "" ) {
		DEBUG("\n[note]: $host_name -> Using custom config dir override = $dir\n\n");
		our $losf_custom_config_dir = $dir;
	    }
	}

	# All Done.
	
	$osf_membership_init = 1;

	# Query node type regex if requested via command-line
	# argument; otherwise, output node_type for locally running
	# host.

	if ( defined $ENV{'LOSF_NODE_TYPE_REGEX_QUERY'} ) {
	    my $node_type=shift;

	    my $regex = query_regex_for_node_type($node_cluster,$node_type);
	    print "$regex\n";
	    if( "$regex" eq "unknown") {exit 1;}
	} else {
	    if($standalone == 1) {
		print "[LosF] Node type:       $node_cluster -> $node_type\n";
		print "[LosF] Config dir:      $losf_custom_config_dir\n";
	    }
	}

	return($node_cluster,$node_type);
	
    }
}

1;


