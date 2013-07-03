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
use LosF_paths;

use lib "$osf_log4perl_dir";
use lib "$osf_ini4perl_dir";
use lib "$osf_utils_dir";
use lib "$osf_term_prompt_dir";

use LosF_node_types;
use LosF_utils;
use LosF_rpm_utils;
use history_utils;
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

    print "     addpkg     [package]         Add new OS package (and dependencies)\n";
    print "     delpkg     [package]         Remove previously added OS package\n";
    print "     addgroup   [ group ]         Add new OS group (and dependencies)\n";
    print "     updatepkg  [package]         Update specific OS packages (and dependencies)\n";
    print "     config-upgrade               Upgrade existing packages.config to latest configuration format\n";
    print "     updatepkgs                   Update all local OS packages (and dependencies)\n";

    print "\n";

    print color 'bold blue';
    print "  Local RPM Customization:\n";
    print color 'reset';

    print "     These commands update the non-distro (custom) RPM configuration\n";
    print "     for the local node type on which the command is executed:\n";
    print "\n";

    print "     addrpm    <OPTIONS> [rpm]   Add a new custom RPM for current node type\n";
    print "     showalias                   Show all currently defined aliases\n";
    print "\n";
    print "     OPTIONS:\n";
    print "        --all                             Add rpm for all node types\n";
    print "        --upgrade                         Upgrade previous rpm to new version provided\n";
    print "        --yes                             Assume \"yes\" for interactive additions\n";
    print "        --alias    [name]                 Add rpm to alias with given name\n";
    print "        --relocate [oldpath] [newpath]    Change install path for relocatable rpm\n";
    print "        --install                         Configure to use install mode as opposed to the default\n";
    print "                                          upgrade mode for RPM installations. Allows multiple\n";
    print "                                          RPMs of the same name to be installed.\n";

    print color 'bold blue';
    print "  Batch System Interaction:\n";
    print color 'reset';

    print "     These commands provide administrative interaction with the locally\n";
    print "     defined batch system:\n";
    print "\n";
    print "     qclose   [name|all]                  Close specified queue (or all queues)\n";
    print "     qopen    [name|all]                  Open  specified queue (or all queues)\n";
    print "\n";
    print "     hlog   <host>                        Display open/close log history\n";
    print "     hclose <OPTIONS> [host]              Close specified host from scheduling\n";
    print "     hopen  <OPTIONS> [host]              Open specified host from scheduling\n";
    print "     hcheck                               Check for newly closed hosts in batch system\n";
    print "\n";
    print "     OPTIONS:\n";
    print "        --comment [comment]               Comment string associated with open/closure\n";
    print "        --date    [YYYY-MM-DD HH:MM]      Override current default timestamp\n";
    print "        --nocertify                       Skip host certification when opening\n";
    print "        --noerror                         Do not flag host as errored when closing\n";
    print "        --logonly                         Log entry only - does not make batch system changes\n";

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
	    $filename = "$osf_custom_config_dir/ips."."$node_cluster";
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
    my $kernel_options_post= query_cluster_config_kernel_boot_options_post ($node_cluster,$node_type);
    my $dns_options        = query_cluster_config_dns_options         ($node_cluster,$node_type);

    print "\n";
    print "   --> Kickstart      = $kickstart\n";
    print "   --> Profile        = $profile\n";
    print "   --> Name Server    = $name_server (search = $name_server_search)\n";

    my $kopts    = "";
    my $dns_opts = "";

    if( $kernel_options ne "" ) {
	print "   --> Kernel Options = $kernel_options\n";
	$kopts = " --kopts=$kernel_options";
    }

    if( $kernel_options_post ne "" ) {
	print "   --> Kernel Post Options = $kernel_options_post\n";
	$kopts = "$kopts --kopts-post=$kernel_options_post";
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

sub update_os_config {

    begin_routine();

# 
#   FORMAT 1.1 - February 2013
#
#   Example format below (rpmname version release arch)....
#
#   compute=libxml2 version=2.7.6 release=8.el6_3.4 arch=x86_64
#   compute=libxml2-python version=2.7.6 release=8.el6_3.4 arch=x86_64
#   compute=abrt version=2.0.8 release=6.el6.centos arch=x86_64
#   compute=abrt-addon-ccpp version=2.0.8 release=6.el6.centos arch=x86_64
#   compute=abrt-addon-kerneloops version=2.0.8 release=6.el6.centos arch=x86_64
#   compute=abrt-addon-python version=2.0.8 release=6.el6.centos arch=x86_64

    print "** Upgrading OS package config file format to latest version (1.1)\n";
    my $section = "OS Packages";

    INFO("   Reading OS package config file -> $osf_custom_config_dir/os-packages/"."$node_cluster/packages.config\n");
    my @os_rpms = query_cluster_config_os_packages($node_cluster,$node_type);

    # Check and update all OS packages for all currently defined node types

    if(! $local_os_cfg->SectionExists($section) ) {
	INFO("   --> No [$section] Packages currently defined - ignoring config upgrade request\n");
	return;
    }

    my @node_types_in   = $local_os_cfg->Parameters($section);

    # Don't bother with packages defined for removal

    my @node_types      = ();

    foreach $type (@node_types_in) {
	if ( $type =~ /(\S+)_remove\b/ ) {
	    print "Skipping $type...\n";
	} else {
	    push(@node_types,$type);
	}
    }

    my @rpm_array       = ();
    my $rpm             = "";
    my $desired_version = "";
    my $desired_release = "";
    my $desired_arch    = "";
    my $file_upgraded   = 0;
    
    foreach $type (@node_types) {
	INFO("   --> Checking node type: $type\n");

	@rpms_defined = ();
	@rpms_defined = $local_os_cfg->val($section,$type);

	$num_rpms = @rpms_defined;

	DEBUG("       --> # of RPMs = $num_rpms\n");

	$local_os_cfg->delval($section,$type);

	foreach $entry (@rpms_defined) {

	    $desired_version = "";
	    $desired_release = "";
	    $desired_arch    = "";

	    @rpm_array = ();
	    @rpm_array = split(/\s+/,$entry);
	    $rpm       = $rpm_array[0];
	    
	    INFO("   --> Checking $type=$rpm\n");

	    shift @rpm_array;

	    foreach $option (@rpm_array) {
		if( $option =~ m/version=(\S+)/ ) { 
		    $desired_version = $1;
		    DEBUG("            --> found version = $1\n");
		} elsif ( $option =~ m/release=(\S+)/ ) { 
		    $desired_release = $1;
		    DEBUG("            --> found release = $1\n");
		} elsif ( $option =~ m/arch=(\S+)/ ) {
		    $desired_arch = $1;
		}
	    }

	    if( $desired_version eq "" || $desired_release eq "" || $desired_arch eq "" ) {
		$file_upgraded = 1;
		INFO("   --> Needs upgrade\n");

		my $arch        = rpm_arch_from_filename($rpm);
		my $filename    = "$rpm_topdir/$arch/$rpm.rpm";
		my @desired_rpm = rpm_version_from_file($filename);

		my $updated_fmt = "$desired_rpm[0] version=$desired_rpm[1] release=$desired_rpm[2] arch=$desired_rpm[3]";

		INFO("Upgrading: $updated_fmt\n");

		if($local_os_cfg->exists($section,$type)) {
		    $local_os_cfg->push($section,$type,$updated_fmt);
		} else {
		    $local_os_cfg->newval($section,$type,$updated_fmt);
		}
	    } else {
		if($local_os_cfg->exists($section,$type)) {
		    $local_os_cfg->push($section,$type,"$rpm @rpm_array");
		} else {
		    $local_os_cfg->newval($section,$type,"$rpm @rpm_array");
		}
	    }
	}

    }  # end loop over all node types

    my $new_file  = "$osf_custom_config_dir/os-packages/$node_cluster/packages.config.new";
    my $ref_file  = "$osf_custom_config_dir/os-packages/$node_cluster/packages.config";
    my $hist_dir  = "$osf_custom_config_dir/os-packages/$node_cluster/previous_revisions";

    $local_os_cfg->WriteConfig($new_file) || MYERROR("Unable to write file $new_file");

    update_losf_config_file($new_file,$ref_file,$hist_dir,"OS");

    if($file_upgraded) {
	print "\n\nOS config file upgrade complete\n";
    } else {
	print "\n\nOS config file check complete - no format changes required\n";
    }

    end_routine();

} # end update_os_config

sub update_custom_config_section {
    my $section = shift;
    begin_routine();

    # Check and update all Custom RPM packages for all currently defined node types

    if(! $local_custom_cfg->SectionExists($section) ) {
	INFO("   --> No [$section] section currently defined - ignoring config upgrade request\n");
	return;
    }
    
    my @node_types = ();
    @node_types = $local_custom_cfg->Parameters($section);
    
    my @rpm_array       = ();
    my $rpm             = "";
    my $desired_version = "";
    my $desired_release = "";
    my $desired_arch    = "";
    my $file_upgraded   = 0;
    
    foreach $type (@node_types) {
	INFO("   --> Checking node type: $type\n");

	@rpms_defined = ();
	@rpms_defined = $local_custom_cfg->val($section,$type);

	$num_rpms = @rpms_defined;

	INFO("       --> # of RPMs = $num_rpms\n");

	$local_custom_cfg->delval($section,$type);

	foreach $entry (@rpms_defined) {

	    # Skip any updates for package aliases (those that begin with @).

	    if ( $entry =~ m/^@(\S+)/ ) {
		if($local_custom_cfg->exists($section,$type)) {
		    $local_custom_cfg->push($section,$type,$entry);
		} else {
		    $local_custom_cfg->newval($section,$type,$entry);
		}
		next;
	    }

	    $desired_name    = "";
	    $desired_version = "";
	    $desired_release = "";
	    $desired_arch    = "";

	    @rpm_array = ();
	    @rpm_array = split(/\s+/,$entry);
	    $rpm       = $rpm_array[0];
	    
	    INFO("   --> Checking $type=$rpm\n");

	    # Expected file format:
	    # 
	    # nodetype=rpmname version=rpmversion release=rpmrelease arch=rpmarch md5sum [optional rpm install options]

	    shift @rpm_array;

	    if(@rpm_array gt 0 ) {
		if ( $rpm_array[0] =~ m/name=(\S+)/ ) {
		    $desired_name = $1;
		}
		if ( $rpm_array[1] =~ m/version=(\S+)/ ) {
		    $desired_version = $1;
		}
		
		if ( $rpm_array[2] =~ m/release=(\S+)/ ) {
		    $desired_release = $1;
		}
		
		if ( $rpm_array[3] =~ m/arch=(\S+)/ ) {
		    $desired_arch = $1;
		}
	    }

	    # Remove any of the above options

	    my @remaining_options = ();
	    foreach $value (@rpm_array) {
		if ( $value !~ m/name=(\S+)/ &&
		     $value !~ m/version=(\S+)/ &&
		     $value !~ m/release=(\S+)/ &&
		     $value !~ m/arch=(\S+)/ ) {
		    push(@remaining_options,$value);
		}
	    }

	    if( $desired_version eq "" || $desired_release eq "" || 
		$desired_arch    eq "" || $desired_name    eq "" ) {
		$file_upgraded = 1;
		INFO("   --> Needs upgrade\n");

		my $arch        = rpm_arch_from_filename($rpm);
		my $filename    = "$rpm_topdir/$arch/$rpm.rpm";
		my @desired_rpm = rpm_version_from_file($filename);

		my $updated_fmt = "$rpm name=$desired_rpm[0] version=$desired_rpm[1] release=$desired_rpm[2] arch=$desired_rpm[3]";
		INFO("Upgrading: $updated_fmt\n");

		# append md5sum and any remaining options

		foreach $option (@remaining_options) {
		    $updated_fmt = "$updated_fmt $option";
		}

		if($local_custom_cfg->exists($section,$type)) {
		    $local_custom_cfg->push($section,$type,$updated_fmt);
		} else {
		    $local_custom_cfg->newval($section,$type,$updated_fmt);
		}
	    } else {
		if($local_custom_cfg->exists($section,$type)) {
		    $local_custom_cfg->push($section,$type,"$rpm @rpm_array");
		} else {
		    $local_custom_cfg->newval($section,$type,"$rpm @rpm_array");
		}
	    }
	}

    }  # end loop over all node types

    end_routine();
    return;
}

sub update_custom_config {

    begin_routine();

    print "** Upgrading Custom RPM package config file format to latest version (1.1)\n";
    INFO("   Reading Custom RPM  package config file -> $osf_custom_config_dir/custom-packages/"."$node_cluster/packages.config\n");

    my @custom_rpms = query_cluster_config_custom_packages($node_cluster,$node_type);

    # Update all custom packages and alias definitions to the latest format

    $file_upgraded = 0;

    update_custom_config_section("Custom Packages");
    update_custom_config_section("Custom Packages/Aliases");
    update_custom_config_section("Custom Packages/uninstall");

    my $new_file  = "$osf_custom_config_dir/custom-packages/$node_cluster/packages.config.new";
    my $ref_file  = "$osf_custom_config_dir/custom-packages/$node_cluster/packages.config";
    my $hist_dir  = "$osf_custom_config_dir/custom-packages/$node_cluster/previous_revisions";

    $local_custom_cfg->WriteConfig($new_file) || MYERROR("Unable to write file $new_file");

    if ( ! -s $new_file ) { MYERROR("Error accessing valid Custom RPM file for update: $new_file"); }
    if ( ! -s $ref_file ) { MYERROR("Error accessing valid Custom RPM file for update: $ref_file"); }
    
    if ( compare($new_file,$ref_file) != 0 ) {
	
	if ( ! -d "$hist_dir") {
	    mkdir("$hist_dir",0700);
	}

	my $timestamp=`date +%F:%H:%M`;
	chomp($timestamp);
	print "   --> Updating Custom RPM config file...\n";
	rename($ref_file,$hist_dir."/packages.config.".$timestamp) || 
	    MYERROR("Unable to save previous OS config file\n");
	rename($new_file,$ref_file)                 || 
	    MYERROR("Unaable to update Custom RPM config file\n");
	print "Copy of original configuration file stored in $hist_dir....\n";
    } else {
	unlink($new_file) || MYERROR("Unable to remove temporary file: $new_file\n");
    }

    if ( $file_upgraded) {
	print "\n\nCustom RPM config file upgrage complete\n";
    } else {
	print "\n\nCustom RPM config file check complete - no format changes required\n";
    }

    end_routine();

} # end update_os_config


sub update_distro_packages {

    begin_routine();
    my $package = shift;

    INFO("\n** Requesting update for local OS pacakge: $package\n");
    SYSLOG("Requesting update for local OS pacakge: $package");

    if( "$package" eq "ALL" ) {
	$package = "";
    }

    # the yum-plugin-downloadonly package is required to support
    # auto-addition of distro packages...

    my $check_pkg = "yum-plugin-downloadonly";
    my @igot = is_rpm_installed($check_pkg);

    if ( @igot  eq 0 ) {
	MYERROR("The $check_pkg rpm must be installed locally in order to use \"losf addpkg\" functionality");
    }

    my $tmpdir = File::Temp->newdir(DIR=>$dir, CLEANUP => 1) || MYERROR("Unable to create temporary directory");
    INFO("   --> Temporary directory for yum downloads = $tmpdir\n");

    my $cmd="yum -y -q --downloadonly --downloaddir=$tmpdir --skip-broken update $package >& /dev/null";
    DEBUG("   --> Running yum command \"$cmd\"\n");

   `$cmd`;

    # Now check to see if we downloaded anything

    my @newfiles = <$tmpdir/*>;

    my $extra_deps = @newfiles - 1;

    if ( @newfiles == 0) {
	INFO("   --> no new os packages found...exiting\n");
	return;
    }

    my $rpm_count = @newfiles;
    INFO("   --> $rpm_count packages successfully downloaded from repository\n");

    INFO("\n   --> Cluster = $node_cluster, Node Type = $node_type\n");
    INFO("\n   --> Would you like to add the following RPM(s) to your local LosF config for ".
	 "$node_cluster:$node_type nodes?\n\n");

    foreach $file (@newfiles) {
	print "       $file\n";
    }

    my $response = ask_user_for_yes_no("Enter yes/no to confirm: ",1);

    if( $response == 0 ) {
	INFO("   --> Did not add new OS packages to LosF to config, terminating....\n");
	exit(-22);
    } 

    print "\n";

    # Now, read current configfile for OS packages

    my $host_name;
    chomp($host_name=`hostname -s`);

    INFO("   Reading OS package config file -> $osf_custom_config_dir/os-packages/"."$node_cluster/packages.config\n");
    my @os_rpms = query_cluster_config_os_packages($node_cluster,$node_type);

    # Upgrade: since we are using arrays for input values, upgrade
    # means removing all values, and re-inserting desired values.

    my $section = "OS Packages";
    my $name    = $node_type;
    DEBUG("       --> Removing previous entries for $name...\n");

    $local_os_cfg->delval($section,$name);

    # Initialize flag array to identify whether existing os packages
    # are being updated or not.

    my @flag = (0) x @os_rpms;

    my @os_pkgs_new = ();	# temp array to hold os packages for new config

    foreach $file (@newfiles) {
	my @version_info = rpm_version_from_file($file);
	my $rpm_package  = rpm_package_string_from_header(@version_info);
	
	INFO("   --> Updating ".rpm_package_string_from_header(@version_info)."\n");

	my $rpm_name    = $version_info[0];
	my $rpm_arch    = $version_info[3];

	my $old_rpm       = "";
	my $is_upgrade    = 0;
	my $count         = 0;

	my $config_string = "$rpm_name version=$version_info[1] release=$version_info[2] arch=$version_info[3]";

###	push(@os_pkgs_new,$rpm_package);
	push(@os_pkgs_new,"$config_string");

	foreach $rpm (@os_rpms) {
	    my @rpm_array  = split(/\s+/,$rpm);
###	    if ($rpm =~ /^$rpm_name-(\S+).($rpm_arch)$/ ) {
	    if ($rpm_array[0] eq $rpm_name && "arch=$rpm_arch" eq $rpm_array[3]) {
		INFO("       --> Configuring update for $rpm_package (previously $rpm)\n");
		$is_upgrade   = 1;
		$old_rpm      = $rpm;
		$flag[$count] = 1;
		last;
	    }

	    $count++;
	}

	# Stage downloaded RPM files into LosF repository

	my $basename = basename($file);
	if ( ! -s "$rpm_topdir/$rpm_arch/$basename" ) {
	    INFO("       --> Copying $basename to RPM repository (arch = $rpm_arch) \n");
	    copy($file,"$rpm_topdir/$rpm_arch") || MYERROR("Unable to copy $basename to $rpm_topdir/$rpm_arch\n");
	}

    } # end loop over newly downloaded OS packages


    # We have now flagged the previous os packages which are to be
    # updated with this config change. Update the config in two steps:
    #
    #   (1) add new packages, and
    #   (2) retain old packages which did not get updated


    foreach $rpm (@os_pkgs_new) {
	if($local_os_cfg->exists($section,$name)) {
	    $local_os_cfg->push($section,$name,"$rpm");
	} else {
	    $local_os_cfg->newval($section,$name,"$rpm");
	}
    }
    
    my $count = 0;

    foreach $rpm (@os_rpms) {
	if( ! $flag[$count] ) {
	    if($local_os_cfg->exists($section,$name)) {

		$local_os_cfg->push($section,$name,"$rpm");
	    } else {
		$local_os_cfg->newval($section,$name,"$rpm");
	    }

	}
	$count++;
    }

    # Update LosF config to include newly added distro packages

    my $new_file  = "$osf_custom_config_dir/os-packages/$node_cluster/packages.config.new";
    my $ref_file  = "$osf_custom_config_dir/os-packages/$node_cluster/packages.config";
    my $hist_dir  = "$osf_custom_config_dir/os-packages/$node_cluster/previous_revisions";

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
	rename($ref_file,$hist_dir."/packages.config.".$timestamp) || 
	    MYERROR("Unable to save previous OS config file\n");
	rename($new_file,$ref_file)                 || 
	    MYERROR("Unaable to update OS config file\n");
	print "\n\nOS config update complete; you can now run \"update\" to make changes take effect\n";
    } else {
	unlink($new_file) || MYERROR("Unable to remove temporary file: $new_file\n");
    }

    end_routine();
} # end sub update_all_distro_packages()

sub add_distro_package {

    begin_routine();
    my $package = shift;

    INFO("\n** Checking on possible addition of requested distro package: $package\n");
    SYSLOG("Checking on addition of distro package $package");

    # the yum-plugin-downloadonly package is required to support
    # auto-addition of distro packages...

    my $check_pkg = "yum-plugin-downloadonly";
    my @igot = is_rpm_installed($check_pkg);
#    my @igot = is_os_rpm_installed("$check_pkg.noarch");

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

	INFO("   Reading OS package config file -> $osf_custom_config_dir/os-packages/"."$node_cluster/packages.config\n");
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

		my $config_string = "$rpm_name version=$version_info[1] release=$version_info[2] arch=$version_info[3]";

		if($local_os_cfg->exists("OS Packages","$node_type")) {
		    $local_os_cfg->push("OS Packages",$node_type,$config_string);
		} else {
		    $local_os_cfg->newval("OS Packages",$node_type,$config_string);
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

	my $new_file  = "$osf_custom_config_dir/os-packages/$node_cluster/packages.config.new";
	my $ref_file  = "$osf_custom_config_dir/os-packages/$node_cluster/packages.config";
	my $hist_dir  = "$osf_custom_config_dir/os-packages/$node_cluster/previous_revisions/packages.config";

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

    my $cmd="yum -y -q --downloadonly --downloaddir=$tmpdir groupinstall \"$package\" >& /dev/null";
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

	INFO("   Reading OS package config file -> $osf_custom_config_dir/os-packages/"."$node_cluster/packages.config\n");
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

		my $config_string = "$rpm_name version=$version_info[1] release=$version_info[2] arch=$version_info[3]";

		if($local_os_cfg->exists("OS Packages","$node_type")) {
		    $local_os_cfg->push("OS Packages",$node_type,$config_string);
		} else {
		    $local_os_cfg->newval("OS Packages",$node_type,$config_string);
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

	my $new_file = "$osf_custom_config_dir/os-packages/$node_cluster/packages.config.new";
	my $ref_file = "$osf_custom_config_dir/os-packages/$node_cluster/packages.config";
	my $hist_dir = "$osf_custom_config_dir/os-packages/$node_cluster/previous_revisions";

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

#    print "package = $package\n";

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
    INFO("       --> $osf_custom_config_dir/custom-packages/$node_cluster/packages.config\n");

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
    INFO("   --> Attempting to add ".rpm_package_string_from_header(@version_info)."\n");

    my $rpm_name       = $version_info[0];
    my $rpm_version    = $version_info[1];
    my $rpm_release    = $version_info[2];
    my $rpm_arch       = $version_info[3];

    my $is_upgrade     = 0;
    my $is_multi       = 0;
    my $old_rpm        = "";
    my $uninstall_name = "";
    
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
	    } elsif ($ENV{'LOSF_REGISTER_MULTI'} ) {
		# We only allow a single release of an rpm package
		# version during MULTI installs

		if($rpm_array[1] eq "name=$rpm_name" && $rpm_array[2] eq "version=$rpm_version") {
		    INFO("       --> Previous rpm release detected during MULTI install ($rpm_array[0])\n");
		    INFO("       --> Would you like to register the old version for deletion?\n");

		    my $response = ask_user_for_yes_no("Enter yes/no to confirm: ",1);

		    if( $response == 0 ) {
			INFO("\n");
			INFO("       --> Unable to add MULTI custom rpm $rpm_name.\n");
			INFO("       --> Only one release per package version is allowed. Terminating....\n");
			INFO("\n");
			exit(-23);
		    } else {
			$old_rpm = $rpm_array[0];
			INFO("\n");
			INFO("       --> Choose desired node type to configure package deletion:\n");
			INFO("           [1] ALL\n");
			INFO("           [2] $node_type\n");
			INFO("\n");

			my $response = ask_user_for_integer_input("Enter integer value: ",1,2);
			if($response == 1) {
			    $uninstall_name = "ALL";
			} else {
			    $uninstall_name = "$node_type";
			    INFO("\n");
			}
		    }
		}
		$is_multi   = 1;
	    } else {
		INFO("       --> $rpm_name already configured - ignoring addition request\n");
		#$is_configured = 1;
		return;
	    }
	    if(! $ENV{'LOSF_REGISTER_MULTI'}) {
		last;
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

    if(! $is_upgrade && ! $is_multi) {
	INFO("       --> $rpm_name not previously configured - registering for addition/upgrade\n"); 
    }
	
    my $config_name = $basename;
	
    # Trim suffix of .rpm 
    
    if ($basename =~ m/(\S+).rpm$/ ) {
	$config_name = $1;
    }

    # 2/28/13: add additional required elements to delineate name/version/release/arch

    $config_name = "$config_name name=$rpm_name version=$rpm_version release=$rpm_release arch=$rpm_arch";
    
    # Update config file with new or upgraded package
    
    my $section = "Custom Packages";
    my $name    = $appliance;
    
    if($alias ne "") { 
	$section = $section . "/Aliases";
	$name    = $alias;
    }
    
    # Register updates for custom config input file
    
    if($is_upgrade ||  $ENV{'LOSF_REGISTER_MULTI'} ) { 
	
	# Upgrade/MULTI: since we are using arrays for input values, upgrade
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

		if($is_multi) {
		    INFO("       --> Configured MULTI package update for $rpm_name-$rpm_version-$rpm_release\n");
		} else {
		    INFO("       --> Configured update for $rpm_name (previously $old_rpm)\n");
		}

		# Register old MULI rpm release for deletion as it is
		# deprecated by this new release

		if($ENV{'LOSF_REGISTER_MULTI'}) {
		    INFO("       --> Registering previous $rpm[0] for deletion (node type = $uninstall_name)\n");
		    my $uninstallSection = "Custom Packages/uninstall";

		    if($local_custom_cfg->exists($uninstallSection,$uninstall_name)) {
			$local_custom_cfg->push($uninstallSection,$uninstall_name,$rpm_entry); 
		    } else {
			$local_custom_cfg->newval($uninstallSection,$uninstall_name,$rpm_entry); 
		    }
		}
	    } else {
		DEBUG("       --> Restoring entry for $rpm_name ($rpm_entry)\n");
		if($local_custom_cfg->exists($section,$name)) {
		    $local_custom_cfg->push($section,$name,$rpm_entry); 
		} else { 
		    $local_custom_cfg->newval($section,$name,$rpm_entry); 
		}
	    }
	}

	# Register new MULTI package directly when it is not replacing a previous release....

	if( $old_rpm eq "" ) {
	    if($local_custom_cfg->exists($section,$name)) {
		$local_custom_cfg->push($section,$name,"$config_name $md5sum $default_options");
	    } else {
		$local_custom_cfg->newval($section,$name,"$config_name $md5sum $default_options");
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

    my $new_file = "$osf_custom_config_dir/custom-packages/$node_cluster/packages.config.new";
    my $ref_file = "$osf_custom_config_dir/custom-packages/$node_cluster/packages.config";
    my $hist_dir = "$osf_custom_config_dir/custom-packages/$node_cluster/previous_revisions";

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
    INFO("       --> $osf_custom_config_dir/custom-packages/$node_cluster/packages.config\n");

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

    my $new_file = "$osf_custom_config_dir/custom-packages/$node_cluster/packages.config.new";
    my $ref_file = "$osf_custom_config_dir/custom-packages/$node_cluster/packages.config";
    my $hist_dir = "$osf_custom_config_dir/custom-packages/$node_cluster/previous_revisions";

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

sub update_losf_config_file {
    begin_routine();
    
    my $new_file = shift;
    my $ref_file = shift;
    my $hist_dir = shift;
    my $name     = shift;

    if ( ! -s $new_file ) { MYERROR("Error accessing new config file during update: $new_file"); }
    if ( ! -s $ref_file ) { MYERROR("Error accessing orig config file for update: $ref_file"); }
    
    if ( compare($new_file,$ref_file) != 0 ) {
	
	if ( ! -d "$hist_dir") {
	    mkdir("$hist_dir",0700);
	}
	
	my $timestamp=`date +%F:%H:%M`;
	chomp($timestamp);

	print "   --> Updating $name config file...\n";
	rename($ref_file,$hist_dir."/packages.config.".$timestamp) || 
	    MYERROR("Unable to save previous $name config file\n");
	rename($new_file,$ref_file)                 || 
	    MYERROR("Unaable to update $name config file\n");

	print "Copy of original configuration file stored in $hist_dir....\n";
    } else {
	unlink($new_file) || MYERROR("Unable to remove temporary file: $new_file\n");
    }

    end_routine();
    return;
}

#-------------------------------------------
# Main front-end for losf command-line tool
#-------------------------------------------

my $datestring = "";
my $comment    = "";
my $noerror    = 0;

GetOptions('relocate=s{2}' => \@relocate_options,'all' => \$all,'upgrade' => \$upgrade,
	   'install' => \$install, 'alias=s' => \$alias_option,'yes' => \$assume_yes,
            "comment=s" => \$comment,'date=s' => \$datestring,'nocertify' => \$nocertify,
            "logonly",\$logonly,'noerror',\$noerror) || usage();

# Command-line parsing

if (@ARGV >= 1) {
    $command  = shift@ARGV;
    if(@ARGV >= 1) {
	$argument = "@ARGV";
    } else {
	$argument="";
    }
} else {
    usage();
}

my $logr = get_logger(); $logr->level($ERROR); 
verify_sw_dependencies(); 
(my $node_cluster, my $node_type) = determine_node_membership();

init_local_config_file_parsing       ("$osf_custom_config_dir/config."."$node_cluster");
init_local_os_config_file_parsing    ("$osf_custom_config_dir/os-packages/$node_cluster/packages.config");
init_local_custom_config_file_parsing("$osf_custom_config_dir/custom-packages/$node_cluster/packages.config");

$logr->level($INFO);

switch ($command) {

    # Do the deed
    
    case "add"            { add_node($argument) };
    case "del"            { del_node($argument) };
    case "delete"         { del_node($argument) };
		          
    case "addpkg"         { add_distro_package($argument)     };
    case "addgroup"       { add_distro_group  ($argument)     };
    case "showalias"      { show_defined_aliases()            };
    case "updatepkg"      { update_distro_packages($argument) };
    case "updatepkgs"     { update_distro_packages("ALL")     };
    case "config-upgrade" { 
	update_os_config();
	update_custom_config();
    };

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

	if($install) {
	    if($upgrade) {
		MYERROR("losf: The --upgrade and --install options are mutually exclusive. Please choose only one.");
	    }
	    $ENV{'LOSF_REGISTER_MULTI'} = '1';
	    $options = $options . "INSTALL MULTI";
	}

	if($assume_yes) {
	    $ENV{'LOSF_ALWAYS_ASSUME_YES'} = '1';
	}

	add_custom_rpm  ($argument,$nodetype,$options,$alias);
    }

    case "hlog" {
	if( $argument ne '') {
	    log_dump_state_1_0($argument);
	} else {
	    log_dump_state_1_0();
	}
    }

    case "hcheck" {
	log_check_for_closed_hosts();
    }

    case "hclose"   { 
	if ( $argument eq '') {MYERROR("losf: A hostname must be provided with the the hclose command");}

	my $state=1;
	if($noerror == 1) { $state=2};

	if($comment eq '') {
	    ERROR("TODO: add request for required comment here\n");
	    exit 1;
	}

	# TODO: abstract for alternative resource managers

	my $rc = system("/usr/bin/scontrol update nodename=$argument state=DRAIN reason=\"$comment\"");
	if( $rc != 0) {
	    MYERROR("Unable to close host $argument in SLURM....exiting\n");
	}

	if($datestring ne '') {
	    log_add_node_event($argument,"close",$comment,$state,$datestring);
	} else {
	    log_add_node_event($argument,"close",$comment,$state);
	}

    }

    case "hopen" {
	if ( $argument eq '') {MYERROR("losf: A hostname must be provided with the the hopen command");}

	if($nocertify) {print "TODO: automate recertification here...\n";}

	if($comment eq '') {
	    ERROR("TODO: add request for required comment here\n");
	    exit 1;
	}

	# TODO: abstract for alternative resource managers

#	print "/usr/bin/scontrol update nodename=$argument state=resume reason=\"$comment\"\n";
	my $rc = system("/usr/bin/scontrol update nodename=$argument state=resume reason=\"$comment\"");
	    
	if( $rc != 0) {
	    MYERROR("Unable to open host $argument in SLURM....exiting\n");
	}

	my @hosts=`scontrol show hostname $argument`;
	chomp(@hosts);

	foreach my $myhost (@hosts) {
	    if($datestring ne '') {
		log_add_node_event($myhost,"open",$comment,0,$datestring);
	    } else {
		log_add_node_event($myhost,"open",$comment,0);
	    }
	}

	# notify batch system
	
	if($logonly) {exit 0;}
    }
    
    print "\n[Error]: Unknown command received-> $command\n";

    usage();
    exit(1);
}

