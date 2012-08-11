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
# Node provisioning registration utility.  Presently intended for use with
# cobbler.  
#
# Originally: 12/25/10
# 
# Questions? karl@tacc.utexas.edu
#
# $Id$
#-------------------------------------------------------------------

use warnings;
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
use Term::ANSIColor;
use Getopt::Long;

# Usage()

sub usage {
    print "\n";
    print color 'bold yellow';
    print "  Usage: losf [COMMAND] [ARG]\n\n";
    print color 'reset';
    print "  where available COMMANDs are as follows:\n\n";

    print color 'bold blue';
    print "  Host Registration:\n";
    print color 'reset';

    print "     add [host]                  Register a new host for provisioning\n";
    print "     del [host]                  Delete an existing host\n";
    print "\n";

    print color 'bold blue';
    print "  OS Package Customization:\n";
    print color 'reset';

    print "     These commands update the Linux distro OS package configuration\n";
    print "     for the local node type on which the command is executed:\n";
    print "\n";

    print "     addpkg    [package]         Add new OS package (and dependencies)\n";
    print "     delpkg    [package]         Remove previously added OS package\n";
#    print "     updatepkg [package] Check for newly available distro package (NOT YET SUPPORTED)\n";
    print "     addgroup  [group]           Add new OS group (and dependencies)\n";
    print "\n";

    print color 'bold blue';
    print "  Local RPM Customization:\n";
    print color 'reset';

    print "     These commands update the non-distro (custom) RPM configuration\n";
    print "     for the local node type on which the command is executed:\n";
    print "\n";

    print "     addrpm    <OPTIONS> [rpm]   Add a new custom RPM for current node type\n";
#    print "     addalias  <OPTIONS> [alias] Add a new alias for current node type\n";
    print "     showalias                   Show all currently defined aliases\n";
    print "\n";
    print "     OPTIONS:\n";
    print "        --all                              Add rpm for all node types\n";
    print "        --upgrade                          Upgrade previous rpm to new version provided\n";
    print "        --yes                              Assume \"yes\" for interactive additions\n";
    print "        --alias    [name]                  Add rpm to alias with given name\n";
    print "        --relocate [oldpath] [newpath]     Change install path for relocatable rpm\n";

    print "\n";
    print "\n";
    exit(1);
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

    @igot = is_rpm_installed($package);

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

	my $response = ask_user_for_yes_no("Enter yes/no to confirm: ",1);

	if( $response == 0 ) {
	    INFO("   --> Did not add $package LosF to config, terminating....\n");
	    exit(-22);
	} 

	print "\n";

	# (3) Read relevant configfile for OS packages

	my $host_name;
	chomp($host_name=`hostname -s`);

	INFO("   Reading OS package config file -> $osf_config_dir/os-packages/"."$node_cluster/packages.config\n");
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
###	    my $rpm_version = $version_info[1]."-".$version_info[2];
	    my $rpm_arch    = $version_info[3];

	    my $is_configured = 0;

	    foreach $rpm (@os_rpms) {

		if ($rpm =~ /^$rpm_name-(\S+).($rpm_arch)$/ ) {
		    INFO("       --> $rpm_name already configured - ignoring addition request\n");
#		    push(@rpms_to_update,$file);
#		    $is_configured = 1;
		    last;
#		    return;
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

	my $new_file  = "$osf_config_dir/os-packages/$node_cluster/packages.config.new";
	my $ref_file  = "$osf_config_dir/os-packages/$node_cluster/packages.config";
	my $hist_dir  = "$osf_config_dir/os-packages/$node_cluster/previous_revisions/packages.config";

	$local_os_cfg->WriteConfig($new_file) || MYERROR("Unable to write file $new_file");

	if ( ! -s $new_file ) { MYERROR("Error accessing valid OS file for update: $new_file"); }
	if ( ! -s $ref_file ) { MYERROR("Error accessing valid OS file for update: $ref_file"); }

	if ( compare($new_file,$ref_file) != 0 ) {

	    if ( ! -d "$hist_dir") {
		mkdir("$hist_dir",0700);
	    }

	    my $timestamp=`date +%F:%H:%M`;
	    chomp($timestamp);
	    print "   --> Updating OS config file...\n";
	    rename($ref_file,$hist_dir."/packages.config.".$timestamp) || MYERROR("Unable to save previous OS config file\n");
	    rename($new_file,$ref_file)                 || MYERROR("Unaable to update OS config file\n");
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

	my $response = ask_user_for_yes_no("Enter yes/no to confirm: ",1);

	if( $response == 0 ) {
	    INFO("   --> Did not add $package LosF to config, terminating....\n");
	    exit(-22);
	} 

	print "\n";

	# (3) Read relevant configfile for OS packages

	my $host_name;
	chomp($host_name=`hostname -s`);

	INFO("   Reading OS package config file -> $osf_config_dir/os-packages/"."$node_cluster/packages.config\n");
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
###	    my $rpm_version = $version_info[1]-$version_info[2];
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
	my $hist_dir = "$osf_config_dir/os-packages/$node_cluster/previous_revisions";

	$local_os_cfg->WriteConfig($new_file) || MYERROR("Unable to write file $new_file");

	if ( ! -s $new_file ) { MYERROR("Error accessing valid OS file for update: $new_file"); }
	if ( ! -s $ref_file ) { MYERROR("Error accessing valid OS file for update: $ref_file"); }

	if ( compare($new_file,$ref_file) != 0 ) {

	    if ( ! -d "$hist_dir") {
		mkdir("$hist_dir",0700);
	    }

	    my $timestamp=`date +%F:%H:%M`;
	    chomp($timestamp);
	    print "   --> Updating OS config file...\n";
	    rename($ref_file,$hist_dir."/packages.config.".$timestamp) || MYERROR("Unable to save previous OS config file\n");
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

sub add_custom_rpm {

    begin_routine();
    my $package          = shift;
    my $node_config_type = shift;
    my $options          = shift;
    my $alias            = shift;

    my $basename  = basename($package);
    my $appliance = $node_config_type;

    if ( $node_config_type eq "local" ) {
	$appliance = $node_type;
    } 
	
    INFO("\n** Checking on possible addition of custom RPM package: $basename\n");

    if ( ! -s $package ) {
	MYERROR("Unable to access requested RPM -> $basename\n");
    }

    my $md5sum = md5sum_file($package);

    if( $md5sum ne "" )  {
	INFO("   --> md5sum = $md5sum\n");
    } else {
	MYERROR("   --> invalid md5sum for package\n");
    }

    INFO("   --> Cluster = $node_cluster, Node Type = $appliance\n");
    INFO("\n");
    INFO("   --> Would you like to add $basename \n");
    if( $alias ne "" ) {
	INFO("       to the alias \"$alias\" for $node_cluster?\n\n");
    } else {
	INFO("       to your local LosF config for $node_cluster:".$appliance." nodes?\n\n");
    }

    my $response = ask_user_for_yes_no("Enter yes/no to confirm (or -1 to add to multiple node types): ",2);

    if( $response == 0 ) {
	INFO("   --> Did not add $basename to LosF config, terminating....\n");
	exit(-22);
    } 

    # Read relevant configfile for custom packages

    INFO("\n");
    INFO("   --> Reading Custom package config file:\n");
    INFO("       --> $osf_config_dir/custom-packages/$node_cluster/packages.config\n");

    my @custom_rpms    = {};
    my %custom_aliases = ();

    if( $alias ne "" ) {

	# User is requesting modification of an alias; read existing
	# aliases and build array of associated rpms

	%custom_aliases = query_cluster_config_custom_aliases($node_cluster);
	if ( exists $custom_aliases{$alias} ) {
	    INFO("       --> reading rpms for $alias alias....\n");
	    @custom_rpms = @{$custom_aliases{$alias}};
	}
    } else {
	@custom_rpms = query_cluster_config_custom_packages($node_cluster,$appliance);
    }

    foreach $rpm (@custom_rpms) {
	DEBUG("   --> Existing custom rpm = $rpm\n");
    }

    # check RPM version for the custom package

    my @version_info = rpm_version_from_file($package);
    my $rpm_package  = rpm_package_string_from_header(@version_info);
    INFO("   --> Adding ".rpm_package_string_from_header(@version_info)."\n");

    my $rpm_name    = $version_info[0];
    my $rpm_arch    = $version_info[3];

#    my $is_configured = 0;
    my $is_upgrade = 0;
    my $old_rpm    = "";
    
    foreach $rpm (@custom_rpms) {
	my @rpm_array  = split(/\s+/,$rpm);

#	print "input rpm = $rpm\n";
#	print "rpm_array[0] = $rpm_array[0]\n";
#	print "looking to match $rpm_name-$version_info[1]\n";
	
#	if ($rpm_array[0] =~ /^$rpm_name-$version_info[1]-(\S+).($rpm_arch)$/ ) {
#	print "rpm = $rpm\n";
#	print "looking for $rpm_array[0]\n";
#	print "name = $rpm_name\n";
    
	if ($rpm_array[0] =~ /^$rpm_name-(\S+)-(\S+).($rpm_arch)$/ ) {
	    if( $ENV{'LOSF_REGISTER_UPGRADE'} ) {
		$is_upgrade = 1;
		$old_rpm    = $rpm_array[0];
	    } else {
		INFO("       --> $rpm_name already configured - ignoring addition request\n");
		#$is_configured = 1;
		return;
	    }
	}
    }

    # all custom rpm specifications must include md5 checksums; we
    # also provide default options to use --nodeps and --ignoresize
    
    my $default_options = "NODEPS IGNORESIZE";
    
    if( $options ne "" ) {
	my @custom_options = split(/\s+/,$options);
	foreach $opt (@custom_options) {
	    if($opt eq "") {next;};
	    INFO("   --> Additional user options = $opt\n");
	    $default_options = "$default_options "."$opt";
	}
    }

    if(! $is_upgrade) {
	INFO("       --> $rpm_name not previously configured - registering for addition/upgrade\n"); 
    }
	
    my $config_name = $basename;
	
    # Trim suffix of .rpm 
    
    if ($basename =~ m/(\S+).rpm$/ ) {
	$config_name = $1;
    }
    
    # Update config file with new or upgraded package
    
    my $section = "Custom Packages";
    my $name    = $appliance;
    
    if($alias ne "") { 
	$section = $section . "/Aliases";
	$name    = $alias;
    }
    
    # Register updates for custom config input file
    
    if($is_upgrade) { 
	
	# Upgrade: since we are using arrays for input values, upgrade
	# means removing all values, and re-inserting desired values.
	
	DEBUG("       --> Removing previous entries for $name...\n");
	$local_custom_cfg->delval($section,$name);
	
	foreach $rpm_entry (@custom_rpms) {
	    my @rpm  = split(/\s+/,$rpm_entry);
	    if($rpm[0] eq $old_rpm ) {
		if($local_custom_cfg->exists($section,$name)) {
		    $local_custom_cfg->push($section,$name,"$config_name $md5sum $default_options");
		} else {
		    $local_custom_cfg->newval($section,$name,"$config_name $md5sum $default_options");
		}
		    INFO("       --> Configured update for $config_name (previously $old_rpm)\n");
	    } else {
		DEBUG("       --> Restoring entry for $name ($rpm_entry)\n");
		if($local_custom_cfg->exists($section,$name)) {
		    $local_custom_cfg->push($section,$name,$rpm_entry); 
		} else { 
		    $local_custom_cfg->newval($section,$name,$rpm_entry); 
		}
	    }
	}
    } else {
	if($local_custom_cfg->exists($section,$name)) {
	    $local_custom_cfg->push($section,$name,"$config_name $md5sum $default_options");
	} else {
	    $local_custom_cfg->newval($section,$name,"$config_name $md5sum $default_options");
	}
    }
	
    # Verify this rpm is available in default LosF location

    (my $rpm_topdir) = query_cluster_rpm_dir($node_cluster,$node_type);

    if(! -d "$rpm_topdir/$rpm_arch" ) {
	INFO("  --> Creating rpm housing directory: $rpm_topdir/$rpm_arch");
	mkdir("$rpm_topdir/$rpm_arch",0700) || MYERROR("Unable to create rpm directory: $rpm_topdir/$rpm_arch");
    }

    if ( ! -e "$rpm_topdir/$rpm_arch/$basename" )  {
	INFO("   --> Copying package to default RPM config dir: $rpm_topdir/$rpm_arch\n");
	copy($package,"$rpm_topdir/$rpm_arch") || MYERROR("Unable to copy $basename");
    }

    SYSLOG("User requested addition of custom RPM: $basename (type=$appliance)");

    # Update LosF config to include desired custom package

    my $new_file = "$osf_config_dir/custom-packages/$node_cluster/packages.config.new";
    my $ref_file = "$osf_config_dir/custom-packages/$node_cluster/packages.config";
    my $hist_dir = "$osf_config_dir/custom-packages/$node_cluster/previous_revisions";

    $local_custom_cfg->WriteConfig($new_file) || MYERROR("Unable to write file $new_file");

    if ( ! -s $new_file ) { MYERROR("Error accessing valid OS file for update: $new_file"); }
    if ( ! -s $ref_file ) { MYERROR("Error accessing valid OS file for update: $ref_file"); }

    if ( compare($new_file,$ref_file) != 0 ) {

	if ( ! -d "$hist_dir") {
	    mkdir("$hist_dir",0700);
	}

	my $timestamp=`date +%F:%H:%M`;
	chomp($timestamp);
	print "   --> Updating Custom RPM config file...\n";
	rename($ref_file,$hist_dir."/packages.config.".$timestamp) || MYERROR("Unable to save previous custom config file\n");
	rename($new_file,$ref_file)                || MYERROR("Unable to update custom config file\n");
	print "\n\nCustom RPM config update complete; you can now run \"update\" to make changes take effect\n";
    } else {
	unlink($new_file) || MYERROR("Unable to remove temporary file: $new_file\n");
    }



    end_routine();
    return;
} # end sub add_custom_rpm

sub register_alias {

    MYERROR("This function deprecated....");

    begin_routine();
    my $alias            = shift;
    my $node_config_type = shift;

    my $appliance = $node_config_type;

    if ( $node_config_type eq "local" ) {
	$appliance = $node_type;
    } 
	
    INFO("\n** Checking on possible addition of custom RPM alias: $alias\n");

    INFO("   --> Cluster = $node_cluster, Node Type = $appliance\n");
    INFO("\n");
    INFO("   --> Would you like to add $alias \n");
    INFO("       to your local LosF config for $node_cluster:".$appliance." nodes?\n\n");

    my $response = ask_user_for_yes_no("Enter yes/no to confirm: ",1);

    if( $response == 0 ) {
	INFO("   --> Did not add $alias to LosF config, terminating....\n");
	exit(-22);
    } 

    # Read relevant configfile for custom packages

    INFO("\n");
    INFO("   --> Reading Custom package config file:\n");
    INFO("       --> $osf_config_dir/custom-packages/$node_cluster/packages.config\n");

    my @custom_rpms = {};

    @custom_rpms    = query_cluster_config_custom_packages($node_cluster,$appliance);

    # check to see if alias is already registered

    foreach $rpm (@custom_rpms) {
	if( $rpm =~ m/^@(\S+)/ ) {
	    my $group = $1;
	    if( "$group" eq "$alias" )  {
		INFO("       --> $alias already configured - ignoring addition request\n");
		$is_configured = 1;
		return;
	    }
	}
    }

    if (! $is_configured ) {
	INFO("       --> $alias not previously configured - Registering for addition\n"); 

	if($local_custom_cfg->exists("Custom Packages","$node_type")) {
	    $local_custom_cfg->push("Custom Packages",$appliance,"@"."$alias");
	} else {
	    $local_custom_cfg->newval("Custom Packages",$appliance,"@"."$alias");
	}
    }

    SYSLOG("User requested addition of custom RPM alias: $alias (type=$appliance)");

    # Update LosF config to include desired custom package

    my $new_file = "$osf_config_dir/custom-packages/$node_cluster/packages.config.new";
    my $ref_file = "$osf_config_dir/custom-packages/$node_cluster/packages.config";
    my $hist_dir = "$osf_config_dir/custom-packages/$node_cluster/previous_revisions";

    $local_custom_cfg->WriteConfig($new_file) || MYERROR("Unable to write file $new_file");

    if ( ! -s $new_file ) { MYERROR("Error accessing valid OS file for update: $new_file"); }
    if ( ! -s $ref_file ) { MYERROR("Error accessing valid OS file for update: $ref_file"); }

    if ( compare($new_file,$ref_file) != 0 ) {

	if ( ! -d "$hist_dir") {
	    mkdir("$hist_dir",0700);
	}

	my $timestamp=`date +%F:%H:%M`;
	chomp($timestamp);
	print "   --> Updating Custom RPM config file...\n";
	rename($ref_file,$hist_dir."/packages.config.".$timestamp) || MYERROR("Unable to save previous custom config file\n");
	rename($new_file,$ref_file)                || MYERROR("Unable to update custom config file\n");
	print "\n\nCustom RPM config update complete; you can now run \"update\" to make changes take effect\n";
    } else {
	unlink($new_file) || MYERROR("Unable to remove temporary file: $new_file\n");
    }

    end_routine();
    return;
} # end sub register_alias

sub show_defined_aliases {

    begin_routine();

    my %custom_aliases = ();

    INFO("\n");
    INFO("Querying locally defined aliases for Cluster:$node_cluster\n");

    %custom_aliases = query_cluster_config_custom_aliases($node_cluster);

    foreach my $group ( keys %custom_aliases) {
	my $group_size =  @{$custom_aliases{$group}};
	INFO("   --> $group ($group_size ");
	if($group_size == 1) {
	    INFO("package)\n");
	} else {
	    INFO("packages)\n");
	}
    }

    end_routine();
    return;
} # end sub show_defined_aliases()

#-------------------------------------------
# Main front-end for losf command-line tool
#-------------------------------------------

GetOptions('relocate=s{2}' => \@relocate_options,'all' => \$all,'upgrade' => \$upgrade,
	   'alias=s' => \$alias_option,'yes' => \$assume_yes) || usage();


# Command-line parsing

if (@ARGV >= 1) {
    $command  = shift@ARGV;
    if(@ARGV >= 1) {
	$argument = shift@ARGV;
    }
} else {
    usage();
}

my $logr = get_logger(); $logr->level($ERROR); 
verify_sw_dependencies(); 
(my $node_cluster, my $node_type) = determine_node_membership();


init_local_config_file_parsing       ("$osf_config_dir/config."."$node_cluster");
init_local_os_config_file_parsing    ("$osf_config_dir/os-packages/$node_cluster/packages.config");
init_local_custom_config_file_parsing("$osf_config_dir/custom-packages/$node_cluster/packages.config");

$logr->level($INFO);

switch ($command) {

    # Do the deed
    
    case "add"      { add_node($argument) };
    case "del"      { del_node($argument) };
    case "delete"   { del_node($argument) };

    case "addpkg"   { add_distro_package($argument) };
    case "addgroup" { add_distro_group  ($argument) };
    case "showalias"{ show_defined_aliases()        };
###    case "addalias" { 
###
###	# parse any additional options used with addalias
###
###	my $nodetype = "local";
###
###	if($all) {
###	    $nodetype = "ALL";
###	}
###
###	if($assume_yes) {
###	    $ENV{'LOSF_ALWAYS_ASSUME_YES'} = '1';
###	}
###
###	print "my argument = $argument\n";
###
###	register_alias  ($argument,$nodetype);
###
###    }
    case "addrpm"   { 

	# parse any additional options used with addrpm

	my $options  = "";
	my $nodetype = "local";
	my $alias    = "";

	if(@relocate_options) {
	    $options = "RELOCATE:$relocate_options[0]:$relocate_options[1]";
	}

	if($alias_option) {
	    $alias = $alias_option;
	}

	if($all) {
	    $nodetype = "ALL";
	}

	if($upgrade) {
	    $ENV{'LOSF_REGISTER_UPGRADE'} = '1';
	}

	if($assume_yes) {
	    $ENV{'LOSF_ALWAYS_ASSUME_YES'} = '1';
	}

	add_custom_rpm  ($argument,$nodetype,$options,$alias);
    }

    print "\n[Error]: Unknown command received-> $command\n";

    usage();
    exit(1);
}

