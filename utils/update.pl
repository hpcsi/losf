#!/usr/bin/perl
#-----------------------------------------------------------------------bl-
#--------------------------------------------------------------------------
# 
# LosF - a Linux operating system Framework for HPC clusters
#
# Copyright (C) 2007-2012 Karl W. Schulz
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
#
# Top-level update utility: used to synchronize all packages and
# config files for local node type.
#
# $Id$
#--------------------------------------------------------------------------

use strict;
use OSF_paths;

use File::Basename;
use File::Compare;
use File::Copy;
use File::Temp qw(tempfile);

use lib "$osf_log4perl_dir";
use lib "$osf_ini4perl_dir";
use lib "$osf_utils_dir";

use node_types;
use utils;
use Getopt::Long;

require "$osf_utils_dir/sync_config_utils.pl";

sub usage { 

    print "\n";
    print "Usage: update [OPTIONS]\n\n";
    print "OPTIONS:\n";
    print "  --help                generate help message and exit\n";
    print "\n";
	  
}

# Default logging is set to ERROR

my $logr = get_logger();
$logr->level($INFO);

# Allow for alternate RPM source paths

my $alt_rpm;

if (@ARGV >= 1) {
    my $indir  = shift@ARGV;
    if ( -d $indir) {
	$alt_rpm = $indir;
	ERROR("\n");
	INFO("[update]: Using $alt_rpm as preferential RPM source path\n");
	$ENV{'MODE'} = 'PXE';
	$ENV{'SRC_DIR'} = $alt_rpm;
	ERROR("\n");
    } else {
	ERROR("\n");
	ERROR("[update]: $indir directory not available, ignoring RPM path override request\n");
	ERROR("\n");
    }
}

parse_and_sync_os_packages();
parse_and_sync_custom_packages();
parse_and_sync_const_files();
parse_and_sync_softlinks();
parse_and_sync_services();
parse_and_sync_permissions();

# (Optionally) run custom site-specific utility for the cluster

(my $node_cluster, my $node_type) = determine_node_membership();

my $custom_file = "$osf_top_dir/update.$node_cluster";

if ( -x $custom_file ) {
    INFO("\nRunning update.$node_cluster to perform local customizations for $node_type node type\n");

    TRACE("Running cmd $custom_file\n");
    system($custom_file);
    
}

1;

