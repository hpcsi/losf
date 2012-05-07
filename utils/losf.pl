#!/usr/bin/perl
#-----------------------------------------------------------------------bl-
#--------------------------------------------------------------------------
# 
# LosF - a Linux operating system Framework for HPC clusters
#
# Copyright (C) 2007,2008,2009,2010,2011 Karl W. Schulz
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
# Node provisioning registration utility.  Presently intended for use with
# cobbler.  
#
# Originally: 12/25/10
# 
# Questions? karl@tacc.utexas.edu
#
# $Id$
#-------------------------------------------------------------------

#use warnings;
use Switch;
use OSF_paths;

use lib "$osf_log4perl_dir";
use lib "$osf_ini4perl_dir";
use lib "$osf_utils_dir";
use lib "$osf_term_prompt_dir";

use rpm_topdir;
use node_types;
use utils;
use rpm_utils;
use File::Temp qw(tempfile);
use File::Compare;
use File::Copy;

#require "$osf_utils_dir/utils.pl";
#require "$osf_utils_dir/parse.pl";
#require "$osf_utils_dir/header.pl";

# Lonestar42 settings

$cobbler_profile="centos5-x86_64";
$domainname="ls4.tacc.utexas.edu";
$ip_tool="/home1/0000/build/admin/rpms/lonestar42/tacc_ips";
$mac_addresses="/home1/0000/build/admin/misc/lonestar42/mac-addresses";
$name_server="206.76.192.1";
$losf_dir="/home1/0000/build/admin/hpc_stack";

# Usage()

sub usage {
    print "Host Command Usage: losf [COMMAND] hostname\n\n";
    print "where \"hostname\" is the desired node to edit.\n";
    print "\nCOMMANDS:\n";
    print "    add         Register a new host for provisioning\n";
    print "    del         Delete an existing host\n";
    print "\n";

    print "Distro Command Usage: losf [COMMAND] package-name\n\n";
    print "where \"packagename\" is the desired rpm package name.\n\n";
    print "    addpkg      Add a new package (and dependencies) from Linux distro for current node type\n";
    print "    delpkg      Remove previously added package\n";
    print "    updatepkg   Check for newly available distro package\n";

    print "\n";
}

sub add_node  {
    my $host = shift;
    
    print "\n** Adding new node $host\n";


    # -------------------------
    # Get interface IP/netmask
    # -------------------------

    if ( ! -x $ip_tool ) {
	print "\n[Error]: IP space utility unavailable ($ip_tool)\n\n";
	exit(1);
    }

    $igot=`$ip_tool $host`;

    if($igot =~ m/(\S+)\s*=\s*(\S+)\s*(\S+)/ ) {
	if( "$1" != "$host") {die "Unable to determine IP address for $host\n"};
	$ip = $2;
	$netmask = $3;
    } else {
	die "Unable to determine IP address for $host\n";
    }

    print "   --> IP address  = $ip\n";
    print "   --> Netmask     = $netmask\n";

    #------------------------------------------
    # Membership type - hardcoded, fixe later.
    #------------------------------------------

    if ( $host =~ m/oss(\d+)*/ ) {
	$kickstart="raid1.os.sd.2drives";
    } elsif ( $host =~ m/mds(\d+)*/ ) {
	$kickstart="raid1.os.sd.2drives";
    } elsif ( $host =~ m/login(\d+)*/ ) {
	$kickstart="raid1.os.sd.2drives";
    } elsif ( $host =~ m/data(\d+)*/ ) {
	$kickstart="raid1.os.sd.2drives";
    } elsif ( $host =~ m/gridftp(\d+)*/ ) {
	$kickstart="raid1.os.sd.2drives";
    } else {
	$kickstart="sample.ks"
    } 

    print "   --> Kickstart   = $kickstart\n";

    # ----------------
    # Get MAC Address
    # ----------------

    open(FILE, "<$mac_addresses") or die "\n[Error]: Mac address file unavailable ($mac_adresses)\n\n";

    $found=0;

    while( $line = <FILE> ) {

	if($line =~ m/^$host\s*(\S+)/) {
	    $found=1;
	    $mac=$1;
	}
    }

    if(!$found) { die "\n[Error]: Unable to find mac address for $host (in $mac_addresses)\n\n"};
    close(FILE);

    print "   --> MAC Address = $mac\n";

#    print "   --> [Info]: Using compute node kickstart setup.....)\n";

    $cmd="cobbler system add --name=$host --hostname=$host.$domainname --static=true --mac=$mac --dns=$host.$domainname --subnet=$netmask --profile=$cobbler_profile --ip=$ip --kickstart=/var/lib/cobbler/kickstarts/$kickstart --name-servers=$name_server --name-servers-search=$domainname";

    print "$cmd\n\n";

    my $returnCode = system($cmd);

    print "return = $returnCode\n";
    
}

sub del_node {
    my $host = shift;

    print "\n** Removing existing node $host\n";

    $cmd="cobbler system remove --name=$host";

    `$cmd`;

}

sub add_distro_package {

    begin_routine();
    my $package = shift;

    INFO("\n** Checking on possible addition of requested distro package: $package\n");
    SYSLOG("Checking on addition of distro package $package");

    # the yum-plugin-downloadonly package is required to support
    # auto-addition of distro packages...

    my $check_pkg = "yum-plugin-downloadonly";
    my @igot = is_rpm_installed($check_pkg);
    if ( @igot  == 0 ) {
	MYERROR("The $check_pkg rpm must be installed locally in order to use \"losf addpkg\" functionality");
    }

    # (1) Check if already installed....

    my @igot = is_rpm_installed($package);
    if( @igot >= 1 ) {
	INFO("   --> package $package is already installed locally\n");
	foreach( @igot ) {
	    DEBUG("       --> ".$_->as_nvre."\n");
	}
	MYERROR("   --> use updatepkg to check for a newer distro version\n");
    }

    # (2) Check if it exists in available yum repo...general approach
    # is to try and download the package and any required dependencies
    # into a temporary directory of our own creation.  Then, if we got
    # a hit, ask the user if they want us to add to LosF, otherwise,
    # we punt.

    my $tmpdir = File::Temp->newdir(DIR=>$dir, CLEANUP => 1) || MYERROR("Unable to create temporary directory");
    INFO("   --> Temporary directory for yum downloads = $tmpdir\n");

    my $cmd="yum -y -q --downloadonly --downloaddir=$tmpdir install $package >& /dev/null";
    DEBUG("   --> Running yum command \"$cmd\"\n");

   `$cmd`;

    # Now check to see if we downloaded anything

    my @newfiles = <$tmpdir/*>;

    my $extra_deps = @newfiles - 1;

    if( @newfiles >= 1 ) {

	if( @newfiles == 1 ) {
	    INFO("   --> \"$package\" successfully downloaded from repository\n");
	} else {
	    INFO("   --> \"$package\" and $extra_deps dependencies successfully downloaded from repository\n");
	}

	INFO("\n   --> Cluster = $node_cluster, Node Type = $node_type\n");
	INFO("\n   --> Would you like to add the following RPM(s) to your local LosF config for ".
	     "$node_cluster:$node_type nodes?\n\n");

	foreach $file (@newfiles) {
	    print "       $file\n";
	}

	my $response = ask_user_for_yes_no();

	if( $response == 0 ) {
	    INFO("   --> Did not add $package LosF config, terminating....\n");
	    exit(-22);
	} 

	print "\n";

	# (3) Read relevant configfile for OS packages

	my $host_name;
	chomp($host_name=`hostname -s`);

	INFO("   Reading OS package config file -> $osf_config_dir/OS-packages."."$node_cluster\n");
	my @os_rpms = query_cluster_config_os_packages($node_cluster,$node_type);

	# cache defined OS rpms. If the RPM is available, we derive
	# the version information directly from RPM header; otherwise,
	# we do our best to derive from filename

#	undef %rpm_defined;

	DEBUG("   --> Using $rpm_topdir for top-level RPM dir\n");

	foreach $rpm (@os_rpms) {

	    INFO("   --> Config rpm = $rpm\n");

	    # Did the user give us an ARCH; if not, use default.

###	    my $config_arch;
###
###	    if( $rpm =~ /^\S+.x86_64$/ ) {
###		$config_arch = "x86_64"; 
###	    } elsif( $rpm =~ /^\S+.i386$/ ) {
###		$config_arch = "i386"; 
###	    } elsif( $rpm =~ /^\S+.i686$/ ) {
###		$config_arch = "i686"; 
###	    } elsif( $rpm =~ /^\S+.noarch$/ ) {
###		$config_arch = "noarch"; 
###	    } else {
###		$config_arch = "x86_64";
###	    }
###
###	    INFO("       --> Using arch = $config_arch\n");
###
###	    if ( -s "$rpm_topdir/$config_arch/$rpm.rpm" ) {
###		INFO("       --> $rpm RPM available\n");
###	    } else {
###		INFO("       --> $rpm RPM not available locally\n");
###	    }
###
#	    $rpm_defined{$_} = 1;
	}

	# check RPM version for downloaded packages

###	undef @rpms_to_add;
###	undef @rpms_to_update;

	INFO("\n");

	foreach $file (@newfiles) {
	    my @version_info = rpm_version_from_file($file);
	    my $rpm_package  = rpm_package_string_from_header(@version_info);
	    INFO("   --> Adding ".rpm_package_string_from_header(@version_info)."\n");

	    my $rpm_name    = $version_info[0];
	    my $rpm_version = $version_info[1]-$version[2];
	    my $rpm_arch    = $version_info[3];

	    my $is_configured = 0;

	    foreach $rpm (@os_rpms) {
		if ($rpm =~ /^$rpm_name-(\S+).($rpm_arch)$/ ) {
		    INFO("       --> $rpm_name already configured - ignoring addition request\n");
#		    push(@rpms_to_update,$file);
		    $is_configured = 1;
		    last;
		}
	    }

	    if (! $is_configured ) {
		INFO("       --> $rpm_name not previously configured - Registering for addition\n"); 
		INFO("       --> Adding $file ($node_type)\n");

		if($local_os_cfg->exists("OS Packages","$node_type")) {
		    $local_os_cfg->push("OS Packages",$node_type,$rpm_package);
		} else {
		    $local_os_cfg->newval("OS Packages",$node_type,$rpm_package);
		}

		# Stage downloaded RPM files into LosF repository

		my $basename = basename($file);
		if ( ! -s "$rpm_topdir/$rpm_arch/$basename" ) {
		    INFO("       --> Copying $basename to RPM repository (arch = $rpm_arch) \n");
		    copy($file,"$rpm_topdir/$rpm_arch") || MYERROR("Unable to copy $basename to $rpm_topdir/$rpm_arch\n");
		}
	    }
	
	} # end loop over new packages to configure
	
	# Update LosF config to include newly added distro packages

	my $new_file = "$osf_config_dir/os-packages/$node_cluster/packages.config.new";
	my $ref_file = "$osf_config_dir/os-packages/$node_cluster/packages.config";

	$local_os_cfg->WriteConfig($new_file) || MYERROR("Unable to write file $new_file");

	if ( ! -s $new_file ) { MYERROR("Error accessing valid OS file for update: $new_file"); }
	if ( ! -s $ref_file ) { MYERROR("Error accessing valid OS file for update: $ref_file"); }

	if ( compare($new_file,$ref_file) != 0 ) {
	    my $timestamp=`date +%F:%H:%M`;
	    chomp($timestamp);
	    print "   --> Updating OS config file...\n";
	    rename($ref_file,$ref_file.".".$timestamp) || MYERROR("Unaable to save previous OS config file\n");
	    rename($new_file,$ref_file)                || MYERROR("Unaable to update OS config file\n");
	    print "\n\nOS config update complete; you can now run \"update\" to make changes take effect\n";
	} else {
	    unlink($new_file) || MYERROR("Unable to remove temporary file: $new_file\n");
	}

#	my @os_rpms = query_cluster_config_os_packages($node_cluster,$host_name,$node_type);

    } else {
	INFO("   --> The package \"$package\" is not available locally via yum.\n\n");
	INFO("   --> Please verify that yum is pointed to a valid repository (or mirror)\n");
	INFO("   --> and that the package name you provided is a legitimate distro package.\n");
	MYERROR(" Unable to add $package to local LosF configuration\n");
    }

    end_routine();
}

# Command-line parsing

if (@ARGV >= 2) {
    $command  = shift@ARGV;
    $argument = shift@ARGV;
} else {
    usage();
    exit(1);
}

my $logr = get_logger(); $logr->level($ERROR); 
verify_sw_dependencies(); 
(my $node_cluster, my $node_type) = determine_node_membership();


init_local_config_file_parsing   ("$osf_config_dir/config."."$node_cluster");
init_local_os_config_file_parsing("$osf_config_dir/os-packages/$node_cluster/packages.config");
$logr->level($INFO);

switch ($command) {

#    exit(1);

    # Do the deed
    
    case "add"    { add_node($argument) };
    case "del"    { del_node($argument) };
    case "delete" { del_node($argument) };

    case "addpkg" { add_distro_package($argument) };
    
    
    print "\n[Error]: Unknown command received-> $command\n";
    usage();
    exit(1);
}

