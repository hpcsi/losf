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
# Top-level update utility: used to synchronize all packages and
# config files for local node type.
#--------------------------------------------------------------------------

use strict;
use LosF_paths;

use File::Basename;
use File::Compare;
use File::Copy;
use File::Temp qw(tempfile);
use Term::ANSIColor;

use lib "$losf_log4perl_dir";
use lib "$losf_ini4perl_dir";
use lib "$losf_utils_dir";

use LosF_node_types;
use LosF_utils;
use Getopt::Long;

require "$losf_utils_dir/sync_config_utils.pl";

sub usage { 

    print "\n";
    print "Usage: update [OPTIONS]\n\n";
    print "OPTIONS:\n";
    print "  --help                generate help message and exit\n";
    print "\n";
	  
}

sub display_changes { 

    my $num_changed = shift;
    my $num_tracked = shift;

    if ( $num_changed > 0) {
	print color 'red';
    }

    print "$num_changed";
    print color 'reset';
    print "/$num_tracked";
}

# Only one LosF instance at a time
losf_get_lock();

# Local node membership
(my $node_cluster, my $node_type) = determine_node_membership();

# Default logging is set to ERROR
my $logr = get_logger();

# Check for update skip request

if ( -e "/root/losf-noupdate" ) {
    chomp(my $host_name=`hostname -s`);
    ERROR("Skipping update request on $host_name -> remove /root/losf-noupdate to re-enable.\n");
    exit(0);
}

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

INFO("** Config dir -> $losf_config_dir\n");

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
    print color 'red';
    print "UPDATED";
} else { 
    print color 'green';
    print "OK";
}

print color 'reset';
print ": ";

print "[RPMs: OS ";
display_changes($losf_os_packages_updated,$losf_os_packages_total);         print "  Custom ";
display_changes($losf_custom_packages_updated,$losf_custom_packages_total); print "] ";

print "[Files: ";    display_changes($losf_const_updated,$losf_const_total);             print "] ";
print "[Links: ";    display_changes($losf_softlinks_updated,$losf_softlinks_total);     print "] ";
print "[Services: "; display_changes($losf_services_updated,$losf_services_total);       print "] ";
print "[Perms: ";    display_changes($losf_permissions_updated,$losf_permissions_total); print "] ";

print "-> $node_type";
print "\n";


# (Optionally) run custom site-specific utility for the cluster

###(my $node_cluster, my $node_type) = determine_node_membership();

my $custom_file = "$losf_top_dir/update.$node_cluster";

if ( -x $custom_file ) {
    INFO("\nRunning update.$node_cluster to perform local customizations for $node_type node type\n");

    TRACE("Running cmd $custom_file\n");
    system("$custom_file $node_type");
    
}

# Done with lock

our $LOSF_FH_lock; close($LOSF_FH_lock);

1;

