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
# Utility functions for populating a master /etc/hosts file 
#--------------------------------------------------------------------------

# $Id$

#use strict;
use LosF_paths;
use LosF_node_types;

use lib "$osf_log4perl_dir";
use lib "$osf_ini4perl_dir";
use lib "$osf_utils_dir/";
use File::Temp qw/tempfile/;
use File::Compare;
use File::Copy;

require "$osf_utils_dir/utils.pl";
require "$osf_utils_dir/parse.pl";
require "$osf_utils_dir/header.pl";

my $hostfile_begin_delim='----------begin-sync-losf-$';
my $hostfile_end_delim='------------end-sync-losf-$';

#---------------
# Initialization
#---------------

my $logr = get_logger();

verify_sw_dependencies(); $logr->level($ERROR);
init_local_config_file_parsing("$osf_custom_config_dir/config."."$node_cluster");
$logr->level($INFO);
print_header();


my %managed_hosts = ();
my $assign_from_file = 0;

($fh,$tmpfile) = tempfile();

print "\nMaster Host File Update Mechanism:\n";
print "   --> tmpfile = $tmpfile\n";

# Parse defined Losf network interface settings

if (defined ($myval = $local_cfg->val("Network",assign_ips_from_file)) ) {
    if ( "$myval" eq "yes" ) {
	INFO("   --> IPs assigned from file (ips.$node_cluster)\n");
        if ( ! -e ("$osf_custom_config_dir/ips."."$node_cluster") ) {
	    MYERROR("ips.$node_cluster file does not exist");
	}
	$assign_from_file = 1;
    }
}

if ( $assign_from_file != 1) {
    MYERROR("Assignment of IP addresses is currently only available using the assign_ips_from_file option");
}

###my %interfaces = query_cluster_config_host_network_definitions($node_cluster,$node_type);
###print "just queried\n";

###while ( my ($key,$value) = each(%interfaces) ) {
###    INFO("   --> $key => $value\n");

###     if ( -e $key || -d $key ) {
### 	my $cmd_string = sprintf("chmod %i %s",$value,$key);
### 	system($cmd_string);
###     }
###}

#---------------------------------------------
# Query cobbler for defined hosts/ips
#---------------------------------------------

`cobbler system report >& $tmpfile`;

if ( ! -s $tmpfile ) {
    print "   --> No hosts defined to sync...\n";
    exit(0);
}

open($IN1, "<$tmpfile")  || die "Cannot open $tmpfile for reading\n";

while ($line1 = <$IN1>) {

#    print "$line1";

    if($line1 =~ m/^Name\s+: (\S+)/ ) {
	$current_host=$1;
    }

    if($line1 =~ m/IP Address\s+: (\S+)/ ) {
	$managed_hosts {$current_host} = $1;

	# Special modification for IPoIB interfaces for computes; add
	# entry for IPoIB interface if we know about it.
	
### 	if($current_host =~ m/c(\d\d\d)-(\d\d\d)/ ) {
### 	    my $ipoib_host = "i$1-$2";
### 	    my $result = `$ip_tool $ipoib_host`;
### 	    
### 	    if($result =~ m/$ipoib_host = (\S+) (\S+)/ ) {
### 		$managed_hosts {$ipoib_host} = $1;
### 	    }
### 	}
    }
}

close($IN1);
unlink($tmpfile);

# domainname

my $domainname="";
chomp($domainname=`dnsdomainname`);


if ( $domainname eq "" ) {
    MYERRROR("Unable to ascertain local domainname\n");
}

#------------------------
# Update /etc/hosts file
#------------------------

my $found_delim = 0;
my $infile="/etc/hosts";

open($IN,     "<$infile") || die "Cannot open /etc/hosts file\n";
open($TMPFILE,">$tmpfile") || die "Cannot create tmp file $tmpfile";

while (<$IN>) {
    if(/$hostfile_begin_delim/../$hostfile_end_delim/) {
	$found_delim=1;
	if (/--begin-sync-losf-$/) {
	    print $TMPFILE "#--------------------------------------------------------------begin-sync-losf-\n";
	    print $TMPFILE "#\n";
	    print $TMPFILE "# Auto-generated host entries; please do not edit entries between the begin/end\n";
	    print $TMPFILE "# delimiters as these hosts are managed via PXE installs. However, feel free to\n";
	    print $TMPFILE "# knock yourself out adding customizations to the rest of the file as anything\n";
	    print $TMPFILE "# outside of the delimited section will be preserved.  Power to the people.\n";
	    print $TMPFILE "#\n";

	    foreach $key (sort (keys(%managed_hosts))) {
		print $TMPFILE "$managed_hosts{$key} $key.$domainname $key\n";
	    }
	    print $TMPFILE "#----------------------------------------------------------------end-sync-losf-\n";
	}
    } else {
	print $TMPFILE $_;
    }
}

close($IN);
close($TMPFILE);

if( $found_delim ) {
    if ( compare($infile,$tmpfile) != 0 )  {
	print "--> updating host entries in $infile\n";
	copy($tmpfile,$infile) || die "Cannot copy updated file\n";
    } else {
	print "--> no changes required for $infile\n";
	unlink($tmpfile) || die "Unable to remove temporary file\n";
    }
} else {
    print "[lsof]: warning: no losf delimiters found in file $infile\n";
    unlink($tmpfile) || die "Unable to remove temporary file\n";
}

$size = scalar keys %managed_hosts;

print "--> scan complete (number of defined hosts = $size)\n\n";




