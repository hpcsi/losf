#!/usr/bin/env perl
#-----------------------------------------------------------------------bl-
#--------------------------------------------------------------------------
# 
# LosF - a Linux operating system Framework for HPC clusters
#
# Copyright (C) 2007-2017 Karl W. Schulz <losf@koomie.com>
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
# Wrapper to sync all config files/services.
#--------------------------------------------------------------------------

use strict;
use LosF_paths;

use File::Basename;
use File::Compare;
use File::Copy;
use File::Temp qw(tempfile);

use lib "$losf_utils_dir";

use LosF_node_types;
use LosF_utils;
use LosF_provision;

require "$losf_utils_dir/utils.pl";
require "$losf_utils_dir/parse.pl";
require "$losf_utils_dir/header.pl";
require "$losf_utils_dir/sync_config_utils.pl";

# Only one LosF instance at a time
losf_get_lock();

# Local node membership
(my $node_cluster, my $node_type) = determine_node_membership();

# Check if we need to update multiple node types (chroot environment)

LosF_provision::init_provisioning_system();

my  @update_types   = ($node_type);
our $exec_node_type = $node_type;

if ($losf_provisioner eq "Warewulf" && $node_type eq "master" ) {
    my @ww_node_types = query_warewulf_node_types($node_cluster,$node_type);
    push(@update_types,@ww_node_types);
}

foreach our $node_type (@update_types) {

    our $losf_const_updated           = 0;
    our $losf_const_total             = 0;
    
    our $losf_softlinks_updated       = 0;
    our $losf_softlinks_total         = 0;
    
    our $losf_services_updated        = 0;
    our $losf_services_total          = 0;

    our $losf_permissions_updated     = 0;
    our $losf_permissions_total       = 0;

    # Include delimiter if more than 1 node type to update

    if(@update_types > 1) {
        INFO("-------------------------------------------------------------------------\n");
        INFO("[Applying sync_config_files for node type=$node_type]\n");
        INFO("-------------------------------------------------------------------------\n");
    }

    parse_and_sync_const_files();
    parse_and_sync_softlinks();
    parse_and_sync_services();
    parse_and_sync_permissions();

    if($node_type ne $update_types[$#update_types]) {
        INFO("\n");
    }

}
    
# Done with lock

our $LOSF_FH_lock; close($LOSF_FH_lock);

1;

