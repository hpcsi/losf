#!/usr/bin/perl
#-----------------------------------------------------------------------bl-
#--------------------------------------------------------------------------
# 
# LosF - a Linux operating system Framework for HPC clusters
#
# Copyright (C) 2007-2013 Karl W. Schulz
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
#
# $Id$
#--------------------------------------------------------------------------

#package node_types;
use strict;
use LosF_paths;
use utils;

use lib "$osf_log4perl_dir";
use lib "$osf_ini4perl_dir";
use lib "$osf_utils_dir/";

use base 'Exporter';

require "$osf_utils_dir/utils.pl";
require "$osf_utils_dir/parse.pl";
require "$osf_utils_dir/header.pl";

my $output_mode = $ENV{'LOSF_LOG_MODE'};

determine_node_membership();  

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
#	    $logr->level($ERROR);
	    $logr->level($INFO);
	}

	#$logr->level($DEBUG);

	if ( $osf_membership_init == 1 ) {
	    DEBUG("--> Returning from determine_node_membership\n");
	    return($node_cluster,$node_type);
	}

        #---------------
        # Initialization
        #---------------

	print_header();
	DEBUG("** Node Type Determination\n");
	
	chomp($host_name=`hostname -s`);
	chomp($domain_name=`dnsdomainname`);

        #---------------
        # Global Parsing
        #---------------
	
	init_config_file_parsing("$osf_config_dir/config.machines");
	($node_cluster, $node_type) = query_global_config_host($host_name,$domain_name);

	if($osf_custom_config) {
	    INFO("Cluster:Node_Type   = $node_cluster:$node_type\n");
	    INFO("LosF Config Dir     = $osf_config_dir\n\n");
	}
	
       # All Done.
	
	$osf_membership_init = 1;

	return($node_cluster,$node_type);
	
    }
}

1;


