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
# Utility functions for syncing an individual file.
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

if ($#ARGV != 0) {
    print "Usage: sync_named_file.pl [filename]\n";
    print "\n";
    exit(1);
}

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
    if(@update_types > 1) {
        INFO("-------------------------------------------------------------------------\n");
        INFO("[Applying sync_config_file for node type=$node_type]\n");
        INFO("-------------------------------------------------------------------------\n");
    }

    sync_single_file($ARGV[0],$node_cluster,$node_type);

    if($node_type ne $update_types[$#update_types]) {
        INFO("\n");
    }
}

BEGIN {

    sub sync_single_file {

	begin_routine();

        my $file          = shift;
        my $node_cluster  = shift;
        my $node_type     = shift;
	
        INFO("** Syncing configuration files ($node_cluster:$node_type)\n");

	# Make sure the requested file has valid config...

	init_local_config_file_parsing("$losf_custom_config_dir/config."."$node_cluster");
	my @sync_files         = query_cluster_config_const_sync_files($node_cluster,$node_type);
	my @sync_files_partial = query_cluster_config_partial_sync_files($node_cluster,$node_type);

	my $found=0;

	# Support for chroot (e.g. alternate provisioning mechanisms).

	my $chroot = "";

	if($LosF_provision::losf_provisioner eq "Warewulf" && requires_chroot_environment() ) {
	    $chroot     = query_warewulf_chroot($node_cluster,$node_type);
	    DEBUG("   --> using alternate chroot for type = $node_type, chroot = $chroot\n");
	}

	# partially synced file? we do this first as a partial sync
	# request trumps a normal sync request.

	if (grep {$_ eq $file } @sync_files_partial ) {
	    $found=1;
	    sync_partial_file(chroot . $file);
	    return;  
	}

	# normal const file?

	if (grep {$_ eq $file } @sync_files ) {
	    $found=1;
	    sync_const_file($chroot . $file,$node_cluster,$node_type);
	    return;  
	}

	if (! $found) { 
	    MYERROR("$file not under LosF control - not syncing");
	}
    }

}

# Done with lock

our $LOSF_FH_lock; close($LOSF_FH_lock);
