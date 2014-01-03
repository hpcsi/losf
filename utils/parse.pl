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
#
# Input File Parsing Utilities: Used to query specific variables
# from .ini style configuration files.
#--------------------------------------------------------------------------

use Config::IniFiles;

BEGIN {

    my $osf_init_global_config       = 0;
    my $osf_init_local_config        = 0; 
    my $osf_init_os_local_config     = 0; 
    my $osf_init_custom_local_config = 0; 
    my $osf_init_sync_permissions    = 0;
    my $osf_init_sync_kickstarts     = 0;

    my %osf_file_perms = ();

    sub query_global_config_host {

	begin_routine();

	my $host   = shift;
	my $domain = shift;
	my $logr   = get_logger();
	my $found  = 0;

	# return direcly if we have already been called previously with this

	# karl TODO: cannot return below in losf add host; figure out why...

###	if ($osf_init_global_config == 1) {
###	    print "uh oh koomie\n";
###	    end_routine();
###	    return ($node_cluster,$node_type);
###	}	    
###
	DEBUG("   --> Looking for DNS domainname match...($domain)\n");

	foreach(@Clusters) {

	    my $loc_cluster = $_;

	    if ( ! $global_cfg->SectionExists($loc_cluster) ) {
		DEBUG("No Input section found for cluster $loc_cluster\n");
	    } else {
		DEBUG("   --> Scanning $loc_cluster \n");

		if( $global_cfg->exists($loc_cluster,"domainname") ) {
		    my $loc_domain = $global_cfg->val($loc_cluster,"domainname");

		    if($loc_domain =~ m/$domain/ ) {

			DEBUG("      --> Found a matching domain ($loc_domain)\n");
			DEBUG("   --> Domain found: Looking for host match...($host)\n");

			my @params = $global_cfg->Parameters($loc_cluster);
			my $num_params = @params;

			foreach(@params) {

			    # Skip the domainname entry

			    if ( $_ eq "domainname" ) { next; }

			    # Look for a matching hostname (exact match first)

			    my $loc_name = $global_cfg->val($loc_cluster,$_);
			    DEBUG("      --> Read $_ = $loc_name\n");
			    if("$host" eq "$loc_name") {
				DEBUG("      --> Found exact match\n");
				$node_cluster = $loc_cluster;
				$node_type    = $_;
				$found        = 1;
				last;
			    }
			}

			foreach(@params) {
			    
			    # Skip the domainname entry

			    if ( $_ eq "domainname" ) { next; }

			    my $loc_name = $global_cfg->val($loc_cluster,$_);
			    DEBUG("      --> Read for regex $_ = $loc_name\n");

			    # Look for a matching hostname (regex match second)

			    if ($host =~ m/\b$loc_name/ ) {
				DEBUG("      --> Found regex match\n");
				$node_cluster = $loc_cluster;
				$node_type    = $_;
				$found        = 1;
				last;
			    }
			}
		    }
		} else {
		    MYERROR("No domainname setting defined for cluster $loc_cluster\n");
		}
	    }
	    
	}

	if( $found == 0 ) {
	    MYERROR("Unable to determine node type for this host/domainname ($host/$domain)",
		    "Please verify global configuration settings and local domainname configuration.\n");
	} else {
	    DEBUG("   --> Node type determination successful\n");
	}

	$osf_init_global_config = 1;

	return ($node_cluster,$node_type);
	end_routine();
    }

    #---------------------------------------------
    # Init parsing of Global configuration file
    #---------------------------------------------

    sub init_config_file_parsing {
	use File::Basename;

	begin_routine();

	my $infile    = shift;
	my $logr      = get_logger();
	my $shortname = fileparse($infile);

	DEBUG("   --> Initializing input config file parsing ($shortname)\n");

	if ( ! -e $infile) {
	    ERROR("[ERROR]: The following file is not accessible: $infile\n");
	    ERROR("[ERROR]: Please verify LosF config/ directory is available locally\n\n");
            ERROR("Alternatively, you can use the \"LOSF_CONFIG_DIR\" environment\n");
	    ERROR("variable to override the default LosF config location.\n\n");
	    exit(1);
	}

	$global_cfg = new Config::IniFiles( -file => "$infile" );

	#--------------------------------
	# Global cluster name definitions
	#--------------------------------

	my $section="Cluster-Names";

	if ( $global_cfg->SectionExists($section ) ) {
	    DEBUG("   --> Reading global cluster names\n");

	    @Clusters = split(' ',$global_cfg->val($section,"clusters"));
	    DEBUG(" clusters = @Clusters\n");

	    $num_clusters = @Clusters;
	    if($num_clusters <= 0 ) {
		INFO("   --> No cluster names defined to manage - set clusters variable appropriately\n\n");
		INFO("Exiting.\n\n");
		exit(0);
	    }
	    DEBUG ("   --> $num_clusters clusters defined:\n");
	    foreach(@Clusters) { DEBUG("       --> ".$_."\n"); }
	    
	} else {
	    MYERROR("Corrupt configuration: [$section] section not found");
	}
	
	end_routine();
    };

    #---------------------------------------------
    # Init parsing of Cluster-specific input file
    #---------------------------------------------

    sub init_local_config_file_parsing {
	use File::Basename;

	begin_routine();

	if ( $osf_init_local_config == 0 ) {

	    my $infile    = shift;
	    my $logr      = get_logger();
	    my $shortname = fileparse($infile);
	    
	    DEBUG("   --> Initializing input file config parsing ($infile)\n");
	    
	    verify_file_exists($infile);
	    
	    $local_cfg = new Config::IniFiles( -file => "$infile", 
					       -allowcontinue => 1,
		                               -nomultiline   => 1);
	    $osf_init_local_config = 1;
	}
	
	end_routine();
    };

    #----------------------------------------------------------------
    # Init parsing of Cluster-specific OS package configuration file
    #----------------------------------------------------------------

    sub init_local_os_config_file_parsing {
	use File::Basename;

	begin_routine();

	if ( $osf_init_os_local_config == 0 ) {

	    my $infile    = shift;
	    my $logr      = get_logger();
	    my $shortname = fileparse($infile);
	    
	    DEBUG("   --> Initializing OS config_parsing ($infile)\n");
	    
	    verify_file_exists($infile);
	    
	    $local_os_cfg = new Config::IniFiles( -file => "$infile", 
						  -allowcontinue => 1,
						  -nomultiline   => 1);
	    $osf_init_os_local_config = 1;
	}
	
	end_routine();
    };

    #-------------------------------------------------------------------
    # Init parsing of Cluster-specific Custom package configuration file
    #-------------------------------------------------------------------

    sub init_local_custom_config_file_parsing {
	use File::Basename;

	begin_routine();

	if ( $osf_init_custom_local_config == 0 ) {

	    my $infile    = shift;
	    my $logr      = get_logger();
	    my $shortname = fileparse($infile);
	    
	    DEBUG("   --> Initializing Custom config_parsing ($infile)\n");
	    
	    verify_file_exists($infile);
	    
	    $local_custom_cfg = new Config::IniFiles( -file => "$infile", 
						      -allowcontinue => 1,
						      -nomultiline   => 1);
	    $osf_init_custom_local_config = 1;
	}
	
	end_routine();
    };

    sub query_global_config_os_sync_date {

	begin_routine();

	my $cluster = shift;
	my $host    = shift;
	
	my $logr    = get_logger();
	my $found   = 0;

	INFO("--> Looking for OS Sync Date...($cluster->$host)\n");

	if ( ! $global_cfg->SectionExists("$cluster/os_sync_dates") ) {
	    MYERROR("No Input section found for cluster $cluster/os_sync_dates\n");
	}

	if (defined ($prod_date =  $global_cfg->val("$cluster/os_sync_dates",$host)) ) {
	    DEBUG("-> Read date = $prod_date");
	} else {
	    MYERROR("No sync_date found for host $host");
	}

	return($prod_date);
    }

    sub query_cluster_config_const_sync_files {

	begin_routine();

	my $cluster       = shift;
	my $host          = shift;
		          
	my $logr          = get_logger();
	my @sync_files    = ();
	my @sync_partials = ();

	DEBUG("   --> Looking for defined files to sync...($cluster->$host)\n");

	if ( ! $local_cfg->SectionExists("ConfigFiles") ) {
	    MYERROR("No Input section found for cluster $cluster [ConfigFiles]\n");
	}

	my @defined_files = $local_cfg->Parameters("ConfigFiles");

	my $num_files = @defined_files;

	DEBUG("   --> \# of files defined = $num_files\n");

	foreach(@defined_files) {
	    TRACE("   --> Read value for $_\n");
	    if (defined ($myval = $local_cfg->val("ConfigFiles",$_)) ) {
		TRACE("   --> Value = $myval\n");
		if ( "$myval" eq "yes" ) {
		    TRACE("   --> Sync defined for $_\n");
		    push(@sync_files,$_);
		}
	    } else {
		MYERROR("ConfigFile defined with no value ($_)");
	    }
	}

	end_routine();

	return(@sync_files);
    }

    sub query_cluster_config_os_packages {

	begin_routine();

	my $cluster       = shift;
	my $node_type     = shift;
		          
	my $logr          = get_logger();
	my @rpms_defined  = ();

	DEBUG("   --> Reading config for OS packages to sync...($cluster->$node_type)\n");

	if ( ! $local_os_cfg->SectionExists("OS Packages") ) {
	    MYERROR("No Input section found for cluster $cluster [OS Packages]\n");
	}

#	my @defined_files = $local_cfg->Parameters("OS Packages");
#	my $num_files = @defined_files;
#	INFO("   --> \# of files defined = $num_files\n");

	if($local_os_cfg->exists("OS Packages",$node_type)) {
	    DEBUG("   --> OS packages defined for node type = $node_type\n");
	    @rpms_defined = $local_os_cfg->val("OS Packages",$node_type);

	    foreach $rpm (@rpms_defined) {
		DEBUG("       --> Read $rpm from config\n");
	    }

	}

	end_routine();
	return(@rpms_defined);
    }

    sub query_cluster_config_os_packages_remove {

	begin_routine();

	my $cluster       = shift;
	my $node_type     = shift;
		          
	my $logr          = get_logger();
	my @rpms_defined  = ();

	DEBUG("   --> Looking for OS packages to remove...($cluster->$node_type)\n");

	if ( ! $local_os_cfg->SectionExists("OS Packages") ) {
	    MYERROR("No Input section found for cluster $cluster [OS Packages]\n");
	}

	if($local_os_cfg->exists("OS Packages",$node_type."_remove")) {
	    DEBUG("   --> OS packages for removal defined for node type = $node_type\n");
	    @rpms_defined = $local_os_cfg->val("OS Packages",$node_type."_remove");

	    foreach $rpm (@rpms_defined) {
		INFO("       --> Read $rpm from config for deletion\n");
	    }

	}

	end_routine();

	return(@rpms_defined);
    }

    sub query_cluster_config_custom_packages_remove {

	begin_routine();

	my $cluster       = shift;
	my $node_type     = shift;
		          
	my $logr          = get_logger();
	my @rpms_defined  = ();

	my $section       = "Custom Packages/uninstall";

	DEBUG("   --> Looking for Custom packages to remove...($cluster->$node_type)\n");

	if ( ! $local_custom_cfg->SectionExists("$section") ) {
	    MYERROR("No Input section found for cluster $cluster [$section]\n");
	}

	if($local_custom_cfg->exists($section,$node_type)) {
	    DEBUG("   --> Custom packages for removal defined for node type = $node_type\n");
	    @rpms_defined = $local_custom_cfg->val($section,$node_type);

	    foreach $rpm (@rpms_defined) {
		TRACE("       --> Read $rpm from config for deletion\n");
	    }

	}

	end_routine();

	return(@rpms_defined);
    }

    sub query_cluster_config_custom_packages {

	begin_routine();

	my $cluster       = shift;
	my $node_type     = shift;
		          
	my $logr          = get_logger();
	my @rpms_defined  = ();

	DEBUG("   --> Looking for Custom packages to sync...($cluster->$node_type)\n");

	if ( ! $local_custom_cfg->SectionExists("Custom Packages") ) {
	    MYERROR("No Input section found for cluster $cluster [OS Packages]\n");
	}

	if($local_custom_cfg->exists("Custom Packages",$node_type)) {
	    DEBUG("   --> Custom packages defined for node type = $node_type\n");
	    @rpms_defined = $local_custom_cfg->val("Custom Packages",$node_type);

	    foreach $rpm (@rpms_defined) {
		DEBUG("       --> Read $rpm from config\n");
	    }
	}

	end_routine();

	return(@rpms_defined);
    }

    sub query_cluster_config_custom_aliases {

	begin_routine();

	my $cluster       = shift;
	my $logr          = get_logger();
	my @aliases       = ();

	DEBUG("   --> Looking for Custom aliases...($cluster)\n");

	if ( ! $local_custom_cfg->SectionExists("Custom Packages/Aliases") ) {
	    MYERROR("No Input section found for cluster $cluster [Custom Packages/Aliases]\n");
	} 

	@aliases = $local_custom_cfg->Parameters("Custom Packages/Aliases");

	# We have an array for all defined aliases, now hash the rpms for each alias

	my %alias_rpms = ();

	foreach $alias (@aliases) {
	    if(defined ( @myvals = $local_custom_cfg->val("Custom Packages/Aliases",$alias)) ) {
		foreach $rpm (@myvals) {
		    push(@{$alias_rpms{$alias}},$rpm);
		}
	    }
	}

	end_routine();
	return(%alias_rpms);
    }

    sub query_cluster_config_partial_sync_files {

	begin_routine();

	my $cluster       = shift;
	my $host          = shift;
		          
	my $logr          = get_logger();
	my @sync_partials = ();

	DEBUG("   --> Looking for defined files to perform partial sync...($cluster->ALL)\n");

	if ( ! $local_cfg->SectionExists("PartialConfigFiles") ) {
	    DEBUG("No Input section found for cluster $cluster [PartialConfigFiles]\n");
	}

	my @defined_files = $local_cfg->Parameters("PartialConfigFiles");

	my $num_files = @defined_files;

	DEBUG("   --> \# of files defined = $num_files\n");

	foreach(@defined_files) {
	    DEBUG("   --> Read value for $_\n");
	    if (defined ($myval = $local_cfg->val("PartialConfigFiles",$_)) ) {
		DEBUG("   --> Value = $myval\n");
		if ( "$myval" eq "partial" || "$myval" eq "yes" ) {
		    DEBUG("   --> Partial sync defined for $_\n");
		    push(@sync_partials,$_);
		}
	    } else {
		MYERROR("ConfigFile defined with no value ($_)");
	    }
	}

	# Now, check node-type specific configuration

	DEBUG("   --> Looking for defined files to perform partial sync...($cluster->$host)\n");

	if ( ! $local_cfg->SectionExists("PartialConfigFiles/$host") ) {
	    DEBUG("No Input section found for cluster $cluster [PartialConfigFiles/$host]\n");
	}

	my @defined_files = $local_cfg->Parameters("PartialConfigFiles/$host");

	my $num_files = @defined_files;

	DEBUG("   --> \# of files defined = $num_files\n");

	foreach(@defined_files) {
	    DEBUG("   --> Read value for $_\n");
	    if (defined ($myval = $local_cfg->val("PartialConfigFiles/$host",$_)) ) {
		DEBUG("   --> Value = $myval\n");
		if ( "$myval" eq "partial" || "$myval" eq "yes" ) {
		    DEBUG("   --> Partial sync defined for $_\n");
		    push(@sync_partials,$_);
		}
	    } else {
		MYERROR("ConfigFile defined with no value ($_)");
	    }
	}

	end_routine();

	return(@sync_partials);
    }

    sub query_cluster_config_delete_sync_files {

	begin_routine();

	my $cluster       = shift;
	my $host          = shift;
		          
	my $logr          = get_logger();
	my @sync_partials = ();

	DEBUG("   --> Looking for defined files to remove...($cluster->$host)\n");

	if ( ! $local_cfg->SectionExists("ConfigFiles") ) {
	    MYERROR("No Input section found for cluster $cluster [ConfigFiles]\n");
	}

	my @defined_files = $local_cfg->Parameters("ConfigFiles");

	my $num_files = @defined_files;

	DEBUG("   --> \# of files defined = $num_files\n");

	foreach(@defined_files) {
	    DEBUG("   --> Read value for $_\n");
	    if (defined ($myval = $local_cfg->val("ConfigFiles",$_)) ) {
		DEBUG("   --> Value = $myval\n");
		if ( "$myval" eq "delete" ) {
		    DEBUG("   --> Delete file defined for $_\n");
		    push(@sync_deletes,$_);
		}
	    } else {
		MYERROR("ConfigFile defined with no value ($_)");
	    }
	}

	end_routine();

	return(@sync_deletes);
    }

    sub query_cluster_config_softlink_sync_files {

	begin_routine();

	my $cluster        = shift;
	my $host           = shift;
		          
	my $logr           = get_logger();
	my %sync_softlinks = ();

	my @defined_files  = ();
	my $section        = ();

	DEBUG("   --> Looking for defined soft links to sync...($cluster->$host)\n");

	if( $host eq "LosF-GLOBAL-NODE-TYPE" ) {
	    $section = "SoftLinks";

	    if ( ! $local_cfg->SectionExists($section) ) {
		WARN("No global softlinks defined for cluster $cluster\n");
		return(%sync_softlinks);
	    }

	    @defined_files = $local_cfg->Parameters($section);
	} else {
	    $section = "SoftLinks/$host";

	    if ( ! $local_cfg->SectionExists($section) ) {
		DEBUG("   --> No node type specific softlinks defined for cluster $cluster ($host)\n");
		return(%sync_softlinks);
	    }

	    @defined_files = $local_cfg->Parameters($section);
	}

	my $num_files = @defined_files;

	DEBUG("   --> \# of soft links defined = $num_files\n");

	foreach(@defined_files) {
	    TRACE("   --> Read value for $_\n");
	    if (defined ($myval = $local_cfg->val($section,$_)) ) {
		TRACE("   --> Value = $myval\n");
		$sync_softlinks{$_} = $myval;
	    }
	}


	end_routine();
	return(%sync_softlinks);
    }

    sub query_cluster_config_host_network_definitions {

	begin_routine();

	my $cluster       = shift;
	my $host          = shift;
		          
	my $logr          = get_logger();
	my %interfaces    = ();

	INFO("   --> Looking for host interface network definitions...($cluster->$host)\n");

	if ( ! $local_cfg->SectionExists("HostInterfaces") ) {
	    MYERROR("No Input section found for cluster $cluster [HostInterfaces]\n");
	}

	my @defined_hosts = $local_cfg->Parameters("HostInterfaces");

	my $num_hosts = @defined_hosts;

	INFO("   --> \# of hosts defined = $num_hosts\n");

	foreach(@defined_hosts) {
	    DEBUG("   --> Read value for $_\n");
	    if (defined (@myvalues = $local_cfg->val("HostInterfaces",$_)) ) {
		print "size of array = ", @myvalues."\n";
#		push(@interfaces,$_);
###		push(@interfaces,@myvalues);
		$interfaces{$_} = @myvalues[0];
#		DEBUG("   --> Value = $myval\n");
#		if ( "$myval" eq "yes" ) {
#		    INFO("   --> Sync defined for $_\n");
#		    push(@sync_files,$_);
#		}
		
	    } else {
		MYERROR("HostInterfaces defined with no value ($_)");
	    }
	}

	end_routine();

	return(%interfaces);
    }

    sub query_cluster_config_services {

	begin_routine();

	my $cluster = shift;
	my $host    = shift;
	my $logr    = get_logger();

	my %inputs  = ();

	DEBUG("   --> Looking for defined files to sync...($cluster->$host)\n");

	if ( ! $local_cfg->SectionExists("Services") ) {
	    MYERROR("No Input section found for cluster $cluster [Services]\n");
	}

	my @defined_services = ();
	my $section = ();

	if( $host eq "LosF-GLOBAL-NODE-TYPE" ) {
	    $section = "Services";

	    if ( ! $local_cfg->SectionExists($section) ) {
		MYERROR("No Input section found for cluster $cluster [Services]\n");
	    }

	    @defined_services = $local_cfg->Parameters($section);
	} else {

	    $section = "Services/$host";

	    if ( ! $local_cfg->SectionExists($section) ) {
		return(%inputs);
	    }

	    @defined_services = $local_cfg->Parameters($section);
	}

	my $num_entries = @defined_services;

	DEBUG("   --> \# of services defined = $num_entries\n");

	foreach(@defined_services) {
	    TRACE("   --> Read value for $_\n");
	    if (defined ($myval = $local_cfg->val($section,$_)) ) {
		TRACE("   --> Value = $myval\n");
		$inputs{$_} = $myval;
	    } else {
		MYERROR("Services defined with no value ($_)");
	    }
	}

	end_routine();

	return(%inputs);
    }

    sub query_cluster_config_sync_permissions {

	begin_routine();

	if($osf_init_sync_permissions == 0) {

	    my $cluster = shift;
	    my $host    = shift;
	
	    my $logr    = get_logger();
	    
	    %osf_file_perms  = ();

	    DEBUG("   --> Looking for specific permissions to sync...($cluster->$host)\n");
	    
	    if ( ! $local_cfg->SectionExists("Permissions") ) {
		MYERROR("No Input section found for cluster $cluster [Permissions]\n");
	    }
	    
	    my @perms = $local_cfg->Parameters("Permissions");
	    
	    my $num_entries = @perms;
	    
	    DEBUG("   --> \# of file permissions to sync = $num_entries\n");
	    
	    foreach(@perms) {
		DEBUG("   --> Read value for $_\n");
		if (defined ($myval = $local_cfg->val("Permissions",$_)) ) {
		    DEBUG("   --> Value = $myval\n");
		    $osf_file_perms{$_} = $myval;
		} else {
		    MYERROR("Permissions defined with no value ($_)");
		}
	    }
	    $osf_init_sync_permissions=1;
	}# end on first entry

	end_routine();
	return(%osf_file_perms);
    }

    sub query_cluster_rpm_dir {

	begin_routine();

	my $cluster = shift;
	my $type    = shift;

	my $logr    = get_logger();
	my $found   = 0;

	DEBUG("   --> Looking for top-level rpm dir...($cluster)\n");

	# 0.43.0 change - rpm_build_dir is a bit of a misnomer at this
	# point. This path is really just a location where LosF can
	# cache required rpms.  Updating variable name to simply be
	# "rpm_dir"; allowing old name as well for backwards
	# compatibility.

	if (defined ($rpm_topdir = $global_cfg->val("$cluster","rpm_dir_$type")) ) {
	    DEBUG("--> Read node specific topdir = $rpm_topdir\n");
	} elsif (defined ($rpm_topdir = $global_cfg->val("$cluster","rpm_dir")) ) {
	    DEBUG("--> Read topdir = $rpm_topdir\n");
	} elsif (defined ($rpm_topdir = $global_cfg->val("$cluster","rpm_build_dir_$type")) ) {
	    DEBUG("--> Read node specific topdir = $rpm_topdir\n");
	} elsif (defined ($rpm_topdir = $global_cfg->val("$cluster","rpm_build_dir")) ) {
	    DEBUG("--> Read topdir = $rpm_topdir\n");
	} else {
	    MYERROR("No rpm_dir defined for cluster $cluster");
	}

	# 10/5/12: add support for a local cache dir

	if (defined ($rpm_cachedir = $global_cfg->val("$cluster","rpm_cache_dir")) ) {
	    DEBUG("--> Read rpm_cache_dir = $rpm_cachedir\n");
	} else {
	    $rpm_cachedir = NONE;
	}
	    

	return($rpm_topdir,$rpm_cachedir);
    }

    sub query_cluster_config_kickstarts {

	begin_routine();

	my $cluster   = shift;
	my $host_type = shift;
	
	my $logr    = get_logger();
	
	my $kickstart    = "";

	DEBUG("   --> Looking for defined kickstart file...($cluster->$host_type)\n");
	    
	if ( ! $local_cfg->SectionExists("Kickstarts") ) {
	    MYERROR("No Input section found for cluster $cluster [Kickstarts]\n");
	} 
	
	if ( defined ($myval = $local_cfg->val("Kickstarts",$host_type)) ) {
	    DEBUG("   --> Read kickstart   = $myval\n");
	    $kickstart = $myval;
	} else {
	    MYERROR("Kickstart file not defined for node type $host_type - please update config.\n");
	}
	
	$osf_init_sync_kickstarts=1;

	end_routine();
	return($kickstart);
    }

    sub query_cluster_config_profiles {

	begin_routine();

	my $cluster   = shift;
	my $host_type = shift;
	
	my $logr      = get_logger();

	my $profile    = "";

	DEBUG("   --> Looking for defined OS imaging profile...($cluster->$host_type)\n");
	    
	if ( ! $local_cfg->SectionExists("Profiles") ) {
	    MYERROR("No Input section found for cluster $cluster [Profiles]\n");
	} 
	
	if ( defined ($myval = $local_cfg->val("Profiles",$host_type)) ) {
	    DEBUG("   --> Read profile   = $myval\n");
	    $profile = $myval;
	} else {
	    MYERROR("OS profile not defined for node type $host_type - please update config.\n");
	}
	
	end_routine();
	return($profile);
    }

    sub query_cluster_config_name_servers {

	begin_routine();

	my $cluster   = shift;
	my $host_type = shift;

	my $logr      = get_logger();

	my $value     = "";
	my $section   = "Name-Servers";

	DEBUG("   --> Looking for defined name-server profile...($cluster->$host_type)\n");
	    
	if ( ! $local_cfg->SectionExists("$section") ) {
	    MYERROR("No Input section found for cluster $cluster [$section]\n");
	} 
	
	if ( defined ($myval = $local_cfg->val("$section",$host_type)) ) {
	    DEBUG("   --> Read name-server   = $myval\n");
	    $value = $myval;
	} else {
	    MYERROR("Name server not defined for node type $host_type - please update config.\n");
	}
	
	end_routine();
	return($value);
    }

    sub query_cluster_config_name_servers_search {

	begin_routine();

	my $cluster   = shift;
	my $host_type = shift;

	my $logr      = get_logger();

	my $value     = "";
	my $section   = "Name-Servers-Search";

	DEBUG("   --> Looking for defined name-server search profile...($cluster->$host_type)\n");
	    
	if ( ! $local_cfg->SectionExists("$section") ) {
	    MYERROR("No Input section found for cluster $cluster [$section]\n");
	} 
	
	if ( defined ($myval = $local_cfg->val("$section",$host_type)) ) {
	    DEBUG("   --> Read name-server search  = $myval\n");
	    $value = $myval;
	} else {
	    MYERROR("Name server search not defined for node type $host_type - please update config.\n");
	}
	
	end_routine();
	return($value);
    }

    sub query_cluster_config_kernel_boot_options {

	begin_routine();

	my $cluster   = shift;
	my $host_type = shift;

	my $logr      = get_logger();

	my $value     = "";
	my $section   = "Kernel-Boot-Options";

	DEBUG("   --> Looking for defined kernel boot options...($cluster->$host_type)\n");
	    
	if ( ! $local_cfg->SectionExists("$section") ) {
	    DEBUG("No Input section found for cluster $cluster [$section]\n");
	    return($value);
	} 
	
	if ( defined ($myval = $local_cfg->val("$section",$host_type)) ) {
	    DEBUG("   --> Read kernel boot option  = $myval\n");
	    $value = $myval;
	} else {
	    DEBUG("No kernel boot options provided for node type $host_type - please update config.\n");
	}
	
	end_routine();
	return($value);
    }

    sub query_cluster_config_kernel_boot_options_post {

	begin_routine();

	my $cluster   = shift;
	my $host_type = shift;

	my $logr      = get_logger();

	my $value     = "";
	my $section   = "Kernel-Boot-Options-Post";

	DEBUG("   --> Looking for defined kernel boot options...($cluster->$host_type)\n");
	    
	if ( ! $local_cfg->SectionExists("$section") ) {
	    DEBUG("No Input section found for cluster $cluster [$section]\n");
	    return($value);
	} 
	
	if ( defined ($myval = $local_cfg->val("$section",$host_type)) ) {
	    DEBUG("   --> Read kernel boot option  = $myval\n");
	    $value = $myval;
	} else {
	    DEBUG("No kernel boot options provided for node type $host_type - please update config.\n");
	}
	
	end_routine();
	return($value);
    }

    sub query_cluster_local_config_dir {
	begin_routine();

	my $cluster   = shift;
	my $host_type = shift;
        my $host_name = shift;
	my $dir       = "";

	if ( $global_cfg->exists($node_cluster,"config_dir") ) {
	    $dir = $global_cfg->val($node_cluster,"config_dir");
	    DEBUG("   --> global config_dir specified in config.machines ($dir)\n");
	}

	# Now, check for possible custom host-specific override

	if( $global_cfg->SectionExists("$node_cluster/config_dir/custom") ) {
	    DEBUG("   --> override section for config_dir specified in config.machines\n");
	    my @custom_dirs = $global_cfg->Parameters("$node_cluster/config_dir/custom");

	    foreach $name (@custom_dirs) {
		DEBUG("       --> $name -> config_dir override provided\n");
                my $string    = "$node_cluster/config_dir/custom/$name";
		my $local_dir = $global_cfg->val("$node_cluster/config_dir/custom",$name);

		if( ! -d $local_dir ) {
	            WARN("       --> Warning: $local_dir not available locally\n");
		    WARN("       --> Ignoring config_dir customization setting...\n");
		    next;
		}

		if ( $global_cfg->SectionExists($string) ) {
		    if ($global_cfg->exists($string,"hosts") ) {
			my $regex = $global_cfg->val($string,"hosts");
			DEBUG("       --> $name -> hostname regex = $regex\n");

			if ($host_name =~ m/\b$regex\b/ ) {
			    DEBUG("       --> hostname regex match, overriding with -> $local_dir\n");
			    $dir = $local_dir;
			    last;
			    
			}
			
		    }
		}

	    }
	}

	end_routine();
	return($dir);
    }

    sub query_cluster_config_dns_options {

	begin_routine();

	my $cluster   = shift;
	my $host_type = shift;

	my $logr      = get_logger();

	my $value     = "";
	my $section   = "DNS-Enable";

	DEBUG("   --> Looking for DNS options...($cluster->$host_type)\n");
	    
	if ( ! $local_cfg->SectionExists("$section") ) {
	    DEBUG("No Input section found for cluster $cluster [$section]\n");
	    return($value);
	} 
	
	if ( defined ($myval = $local_cfg->val("$section",$host_type)) ) {
	    DEBUG("   --> Read DNS config option  = $myval\n");
	    $value = $myval;
	} else {
	    DEBUG("No DNS options provided for node type $host_type - default is to not include DNS.\n");
	    $value = "no";
	}
	
	end_routine();
	return($value);
    }

}

1;
