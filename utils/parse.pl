#!/usr/bin/perl
#
#-------------------------------------------------------------------
#
# Input File Parsing Utilities: Used to query specific variables
# from .ini style configuration files.
#
# $Id$
#-------------------------------------------------------------------

use Config::IniFiles;

BEGIN {

    my $osf_init_global_config = 0;
    my $osf_init_local_config  = 0; 

    sub query_global_config_host {

	begin_routine();

	my $host   = shift;
	my $domain = shift;
	my $logr   = get_logger();
	my $found  = 0;

	INFO("   --> Looking for DNS domainname match...($domain)\n");

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
			INFO ("   --> Domain found: Looking for host match...($host)\n");

			my @params = $global_cfg->Parameters($loc_cluster);
			my $num_params = @params;

			foreach(@params) {

			    # Skip the domainname entry

			    if ( $_ eq "domainname" ) { next; }

			    # Look for a matching hostname

			    my $loc_name = $global_cfg->val($loc_cluster,$_);
			    DEBUG("      --> Read $_ = $loc_name\n");
			    if("$host" eq "$loc_name") {
				DEBUG("      --> Found exact match\n");
				$node_cluster = $loc_cluster;
				$node_type    = $_;
				$found        = 1;
				last;
			    }
			    elsif ($host =~ m/$loc_name/ ) {
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
	    
	    INFO("   --> Node type determination successful\n");
	    INFO("\n");
	    INFO("   Cluster:Node_Type   = $node_cluster:$node_type\n");
	    INFO("\n");
	}

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

	INFO("   --> Initializing input config_parsing ($shortname)\n");
	
	verify_file_exists($infile);
	
	$global_cfg = new Config::IniFiles( -file => "$infile" );

	#--------------------------------
	# Global cluster name definitions
	#--------------------------------

	my $section="Cluster-Names";

	if ( $global_cfg->SectionExists($section ) ) {
	    INFO("   --> Reading global cluster names\n");

	    @Clusters = split(' ',$global_cfg->val($section,"clusters"));
	    DEBUG(" clusters = @Clusters\n");

	    $num_clusters = @Clusters;
	    if($num_clusters <= 0 ) {
		INFO("   --> No cluster names defined to manage - set clusters variable appropriately\n\n");
		INFO("Exiting.\n\n");
		exit(0);
	    }
	    INFO ("   --> $num_clusters clusters defined:\n");
	    foreach(@Clusters) { INFO("       --> ".$_."\n"); }
	    
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
	    
	    INFO("   --> Initializing input config_parsing ($shortname)\n");
	    
	    verify_file_exists($infile);
	    
	    $local_cfg = new Config::IniFiles( -file => "$infile" );
	    $osf_init_global_config = 1;
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

	INFO("   --> Looking for defined files to sync...($cluster->$host)\n");

	if ( ! $local_cfg->SectionExists("ConfigFiles") ) {
	    MYERROR("No Input section found for cluster $cluster [ConfigFiles]\n");
	}

	my @defined_files = $local_cfg->Parameters("ConfigFiles");

	my $num_files = @defined_files;

	INFO("   --> \# of files defined = $num_files\n");

	foreach(@defined_files) {
	    DEBUG("   --> Read value for $_\n");
	    if (defined ($myval = $local_cfg->val("ConfigFiles",$_)) ) {
		DEBUG("   --> Value = $myval\n");
		if ( "$myval" eq "yes" ) {
		    INFO("   --> Sync requested for $_\n");
		    push(@sync_files,$_);
		}
	    } else {
		MYERROR("ConfigFile defined with no value ($_)");
	    }
	}

	end_routine();

	return(@sync_files);
    }

    sub query_cluster_config_partial_sync_files {

	begin_routine();

	my $cluster       = shift;
	my $host          = shift;
		          
	my $logr          = get_logger();
	my @sync_files    = ();
	my @sync_partials = ();

	INFO("   --> Looking for defined files to perform partial sync...($cluster->$host)\n");

	if ( ! $local_cfg->SectionExists("ConfigFiles") ) {
	    MYERROR("No Input section found for cluster $cluster [ConfigFiles]\n");
	}

	my @defined_files = $local_cfg->Parameters("ConfigFiles");

	my $num_files = @defined_files;

	INFO("   --> \# of files defined = $num_files\n");

	foreach(@defined_files) {
	    DEBUG("   --> Read value for $_\n");
	    if (defined ($myval = $local_cfg->val("ConfigFiles",$_)) ) {
		DEBUG("   --> Value = $myval\n");
		if ( "$myval" eq "partial" ) {
		    INFO("   --> Partial sync requested for $_\n");
		    push(@sync_partials,$_);
		}
	    } else {
		MYERROR("ConfigFile defined with no value ($_)");
	    }
	}

	end_routine();

	return(@sync_partials);
    }



    sub query_cluster_config_services {

	begin_routine();

	my $cluster = shift;
	my $host    = shift;
	
	my $logr    = get_logger();

	my %inputs  = ();

#	my @keys    = ();
#	my @values  = ();

	INFO("   --> Looking for defined files to sync...($cluster->$host)\n");

	if ( ! $local_cfg->SectionExists("Services") ) {
	    MYERROR("No Input section found for cluster $cluster [Services]\n");
	}

	my @defined_services = $local_cfg->Parameters("Services");

	my $num_entries = @defined_services;

	INFO("   --> \# of services defined = $num_entries\n");

	foreach(@defined_services) {
	    DEBUG("   --> Read value for $_\n");
	    if (defined ($myval = $local_cfg->val("Services",$_)) ) {
		DEBUG("   --> Value = $myval\n");
		$inputs{$_} = $myval;
#		push(@keys,$_);
#		push(@values,$myval);
	    } else {
		MYERROR("Services defined with no value ($_)");
	    }
	}

	end_routine();

#	return(@keys,@values);
	return(%inputs);
    }

    sub query_cluster_config_sync_permissions {

	begin_routine();

	my $cluster = shift;
	my $host    = shift;
	
	my $logr    = get_logger();

	my %inputs  = ();

	INFO("   --> Looking for specific permissions to sync...($cluster->$host)\n");

	if ( ! $local_cfg->SectionExists("Permissions") ) {
	    MYERROR("No Input section found for cluster $cluster [Permissions]\n");
	}

	my @perms = $local_cfg->Parameters("Permissions");

	my $num_entries = @perms;

	INFO("   --> \# of file permissions to sync = $num_entries\n");

	foreach(@perms) {
	    DEBUG("   --> Read value for $_\n");
	    if (defined ($myval = $local_cfg->val("Permissions",$_)) ) {
		DEBUG("   --> Value = $myval\n");
		$inputs{$_} = $myval;
	    } else {
		MYERROR("Permissions defined with no value ($_)");
	    }
	}

	end_routine();

	return(%inputs);
    }

    sub query_cluster_rpm_dir {

	begin_routine();

	my $cluster = shift;
	
	my $logr    = get_logger();
	my $found   = 0;

	INFO("--> Looking for top-level rpm dir...($cluster)\n");

	if (defined ($rpm_topdir = $global_cfg->val("$cluster","rpm_build_dir")) ) {
	    DEBUG("--> Read topdir = $rpm_topdir\n");
	} else {
	    MYERROR("No rpm_build_dir defined for cluster $cluster");
	}

	return($rpm_topdir);
    }

}

1;
