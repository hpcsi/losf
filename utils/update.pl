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
#
# Top-level update utility: used to synchronize all packages and
# config files for local node type.
#
# $Id$
#--------------------------------------------------------------------------

use strict;
use LosF_paths;

use File::Basename;
use File::Compare;
use File::Copy;
use File::Temp qw(tempfile);
use Term::ANSIColor;

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

(my $node_cluster, my $node_type) = determine_node_membership();

# Default logging is set to ERROR

my $logr = get_logger();
###$logr->level($INFO);

# Allow for alternate RPM source paths

my $alt_rpm;

if (@ARGV >= 1) {
    my $indir  = shift@ARGV;
    if ( -d $indir) {
	$alt_rpm = $indir;
	INFO("\n");
	INFO("[update]: Using $alt_rpm as preferential RPM source path\n");
	$ENV{'MODE'} = 'PXE';
	$ENV{'SRC_DIR'} = $alt_rpm;
	INFO("\n");
    } else {
	ERROR("\n");
	ERROR("[update]: $indir directory not available, ignoring RPM path override request\n");
	ERROR("\n");
    }
}

# Initialize update tracking flags

our $losf_os_packages_updated     = 0;
our $losf_os_packages_total       = 0;

our $losf_custom_packages_updated = 0;
our $losf_custom_packages_total   = 0;

our $losf_const_updated           = 0;
our $losf_const_total             = 0;

our $losf_softlinks_updated       = 0;
our $losf_softlinks_total         = 0;

our $losf_services_updated        = 0;
our $losf_services_total          = 0;

our $losf_permissions_updated     = 0;
our $losf_permissions_total       = 0;

# Check for any necessary updates

parse_and_uninstall_os_packages();
parse_and_uninstall_custom_packages();

parse_and_sync_os_packages();
parse_and_sync_custom_packages();
parse_and_sync_const_files();
parse_and_sync_softlinks();
parse_and_sync_services();
parse_and_sync_permissions();

INFO("\n");

if ($losf_os_packages_updated || $losf_custom_packages_updated || $losf_const_updated ||
    $losf_softlinks_updated   || $losf_services_updated        || $losf_permissions_updated ) {
    notify_local_log();
    print_error_in_red("FAILED");
    ERROR(":" );
} else { 
    print color 'green';
    ERROR("OK: ");
    print color 'reset';
}

print "[RPMs: OS $losf_os_packages_updated/$losf_os_packages_total ";
print " Custom $losf_custom_packages_updated/$losf_custom_packages_total] ";
print "[Files: $losf_const_updated/$losf_const_total] ";
print "[Links: $losf_softlinks_updated/$losf_softlinks_total] ";
print "[Services: $losf_services_updated/$losf_services_total] ";
print "[Perms: $losf_permissions_updated/$losf_permissions_total] ";
print "-> $node_type";

print "\n";


# (Optionally) run custom site-specific utility for the cluster

###(my $node_cluster, my $node_type) = determine_node_membership();

my $custom_file = "$osf_top_dir/update.$node_cluster";

if ( -x $custom_file ) {
    INFO("\nRunning update.$node_cluster to perform local customizations for $node_type node type\n");

    TRACE("Running cmd $custom_file\n");
    system($custom_file);
    
}

1;

