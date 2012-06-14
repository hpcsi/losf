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

# Usage()

sub usage {
    print "\nUsage: losf [COMMAND] [ARG]\n\n";
    print "  Available COMMANDS are as follows:\n\n";

    print "  Host Registration:\n";
    print "     add [host]          Register a new host for provisioning\n";
    print "     del [host]          Delete an existing host\n";
    print "\n";

    print "  OS package Customization:\n";
    print "     addpkg    [package] Add a new OS package (and dependencies) from Linux distro for current node type\n";
    print "     delpkg    [package] Remove previously added OS package\n";
    print "     updatepkg [package] Check for newly available distro package (NOT YET SUPPORTED)\n";
    print "\n";
    print "     addgroup  [group]   Add a new OS group (and dependencies) from Linux distro for current node type\n";
    print "\n";

    print "  Local RPM Customization:\n";
    print "     addrpm    [rpm]     Add a new custom RPM for current node type\n";

    print "\n";
}

sub add_node  {
    my $host = shift;
    
    print "\n** Adding new node $host\n";

    chomp($domain_name=`dnsdomainname`);
    ($node_cluster, $node_type) = query_global_config_host($host,$domain_name);

    # 
    # Parse defined Losf network interface settings
    #

    my $filename = "";

    if (defined ($myval = $local_cfg->val("Network",assign_ips_from_file)) ) {
	if ( "$myval" eq "yes" ) {
	    $filename = "$osf_config_dir/ips."."$node_cluster";
	    INFO("   --> IPs assigned from file $filename\n");
	    if ( ! -e ("$filename") ) {
		MYERROR("$filename does not exist");
	    }
	    $assign_from_file = 1;
	}
    }

    if ( $assign_from_file != 1) {
	MYERROR("Assignment of IP addresses is currently only available using the assign_ips_from_file option");
    }

    # -------------------------
    # Get interface IP/netmask
    # -------------------------

    my @ip        = ();
    my @mac       = ();
    my @netmask   = ();
    my @interface = ();

    open($IN,"<$filename") || die "Cannot open $filename\n";

    # example file format....
    # hostname ip mac interface netmask
    # stampede_master 10.42.0.100 00:26:6C:FB:A6:75 eth1 255.255.224.0

    while( $line = <$IN>) {
	if( $line =~ m/^$host\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/ ) {
	    push(@ip       , $1);
	    push(@mac      , $2);
	    push(@interface, $3);
	    push(@netmask  , $4);
#	    push(@enable_dns,$5);
	}
    }

    close($IN);

    my $num_interfaces = @ip;
    my $count = 0;

    if( $num_interfaces ge 1 ) {

	for my $count (0 .. ($num_interfaces-1)) {
	    print "\n";
	    print "   Defined Interface:\n";
	    
	    INFO("   --> IP address        = $ip[$count]\n");
	    INFO("   --> MAC               = $mac[$count]\n");
	    INFO("   --> Interface         = $interface[$count]\n");
	    INFO("   --> Netmask           = $netmask[$count]\n");
	}
    } else {
	ERROR("\n[ERROR]: $host not defined in $filename\n");
	ERROR("[ERROR]: Please define desired network setting in IP config file and retry\n");
	ERROR("\n");
	exit(1);
    }
    
    #-------------------
    # OS Imaging Config
    #-------------------

    my $kickstart          = query_cluster_config_kickstarts          ($node_cluster,$node_type);
    my $profile            = query_cluster_config_profiles            ($node_cluster,$node_type);
    my $name_server        = query_cluster_config_name_servers        ($node_cluster,$node_type);
    my $name_server_search = query_cluster_config_name_servers_search ($node_cluster,$node_type);
    my $kernel_options     = query_cluster_config_kernel_boot_options ($node_cluster,$node_type);
    my $dns_options        = query_cluster_config_dns_options         ($node_cluster,$node_type);

    print "\n";
    print "   --> Kickstart      = $kickstart\n";
    print "   --> Profile        = $profile\n";
    print "   --> Name Server    = $name_server (search = $name_server_search)\n";

    my $kopts    = "";
    my $dns_opts = "";

    if( $kernel_options ne "" ) {
	print "   --> Kernel Options = $kernel_options\n";
	$kopts = "--kopts=$kernel_options --kopts-post=$kernel_options";
    }

    if ($dns_options eq "yes" ) {
	print "   --> DNS enabled    = yes ($host.$domain_name on first defined interface)\n";
	$dns_opts = "--dns=$host.$domain_name";
    } else {
	print "   --> DNS enabled     = no\n";
    }

    $cmd="cobbler system add --name=$host --hostname=$host.$domain_name --interface=$interface[0] --static=true "
	."--mac=$mac[0] $dns_opts " 
	."--subnet=$netmask[0] --profile=$profile --ip-addres=$ip[0] "
	."--kickstart=$kickstart --name-servers=$name_server --name-servers-search=$name_server_search "
	."$kopts";

    my $returnCode = system($cmd);

    if($returnCode != 0) {
	print "\n$cmd\n\n";	
	MYERROR("Cobbler insertion failed ($returnCode)\n");
    }

    # now, add any additional interfaces

    for my $count (1 .. ($num_interfaces-1)) {
	$cmd="cobbler system edit --name=$host --interface=$interface[$count] --static=true "
	    ."--mac=$mac[$count] --subnet=$netmask[$count] --ip-addres=$ip[$count] ";

	#print "\n$cmd\n\n";
	my $returnCode = system($cmd);

	if($returnCode != 0) {
	    print "\n$cmd\n\n";	
	    MYERROR("Cobbler edit for additional network interfaces failed ($returnCode)\n");
	}
    }
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

    if ( @igot  eq 0 ) {
	MYERROR("The $check_pkg rpm must be installed locally in order to use \"losf addpkg\" functionality");
    }

    # (1) Check if already installed....

    my @igot = is_rpm_installed($package);

    if( @igot ne 0 ) {
	INFO("   --> package $package is already installed locally\n");
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
	    DEBUG("   --> Config rpm = $rpm\n");
	}

	# check RPM version for downloaded packages

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

    } else {
	INFO("   --> The package \"$package\" is not available locally via yum.\n\n");
	INFO("   --> Please verify that yum is pointed to a valid repository (or mirror)\n");
	INFO("   --> and that the package name you provided is a legitimate distro package.\n");
	MYERROR(" Unable to add $package to local LosF configuration\n");
    }

    end_routine();
} # end sub add_distr_package

sub add_distro_group {

    begin_routine();
    my $package = shift;

    INFO("\n** Checking on possible addition of requested distro group: $package\n");
    SYSLOG("losf: Checking on addition of distro group $package");

    # the yum-plugin-downloadonly package is required to support
    # auto-addition of distro packages...

    my $check_pkg = "yum-plugin-downloadonly";
    my @igot = is_rpm_installed($check_pkg);

    if ( @igot  eq 0 ) {
	MYERROR("The $check_pkg rpm must be installed locally in order to use \"losf addpkg\" functionality");
    }

    # (1) Check if already installed....yum grouplist doesn't seem to work for this...

#    my @igot = is_rpm_installed($package);

#    if( @igot ne 0 ) {
#	INFO("   --> package $package is already installed locally\n");
#	MYERROR("   --> use updatepkg to check for a newer distro version\n");
#    }

    # (2) Check if it exists in available yum repo...general approach
    # is to try and download the package and any required dependencies
    # into a temporary directory of our own creation.  Then, if we got
    # a hit, ask the user if they want us to add to LosF, otherwise,
    # we punt.

    my $tmpdir = File::Temp->newdir(DIR=>$dir, CLEANUP => 1) || MYERROR("Unable to create temporary directory");
    INFO("   --> Temporary directory for yum downloads = $tmpdir\n");

    my $cmd="yum -y -q --downloadonly --downloaddir=$tmpdir groupinstall $package >& /dev/null";
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

	DEBUG("   --> Using $rpm_topdir for top-level RPM dir\n");

	foreach $rpm (@os_rpms) {
	    DEBUG("   --> Config rpm = $rpm\n");
	}

	# check RPM version for downloaded packages

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
} # end sub add_distr_group

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

    case "addpkg"   { add_distro_package($argument) };
    case "addgroup" { add_distro_group  ($argument) };
    
    
    print "\n[Error]: Unknown command received-> $command\n";
    usage();
    exit(1);
}

