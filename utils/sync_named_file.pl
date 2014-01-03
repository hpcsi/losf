#!/usr/bin/perl
#-----------------------------------------------------------------------bl-
#--------------------------------------------------------------------------
# 
# LosF - a Linux operating system Framework for HPC clusters
#
# Copyright (C) 2007-2013 Karl W. Schulz <losf@koomie.com>
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

use lib "$losf_log4perl_dir";
use lib "$losf_ini4perl_dir";
use lib "$losf_utils_dir";

use LosF_node_types;
use LosF_utils;

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

sync_single_file($ARGV[0]);

BEGIN {

    my $osf_sync_const_file  = 0;
    my $osf_sync_services    = 0;
    my $osf_sync_permissions = 0;

    sub sync_single_file {

	verify_sw_dependencies();
	begin_routine();

        my $file = shift;
	
	if ( $osf_sync_const_file == 0 ) {
	    INFO("** Syncing configuration files (const)\n\n");
	    $osf_sync_const_file = 1;
	}

	# Make sure the requested file has valid config...

	$osf_sync_const_file = 1;

	(my $node_cluster, my $node_type) = determine_node_membership();
	init_local_config_file_parsing("$losf_custom_config_dir/config."."$node_cluster");
	my @sync_files         = query_cluster_config_const_sync_files($node_cluster,$node_type);
	my @sync_files_partial = query_cluster_config_partial_sync_files($node_cluster,$node_type);

	my $found=0;

	# partially synced file? we do this first as a partial sync
	# request trumps a normal sync request.

	if (grep {$_ eq $file } @sync_files_partial ) {
	    $found=1;
	    sync_partial_file($file);
	    exit(0);  
	}

	# normal const file?

	if (grep {$_ eq $file } @sync_files ) {
	    $found=1;
	    sync_const_file($file);
	    exit(0);  
	}

	if (! $found) { 
	    MYERROR("$file not under LosF control - not syncing");
	}
    }

}

# Done with lock

our $LOSF_FH_lock; close($LOSF_FH_lock);
