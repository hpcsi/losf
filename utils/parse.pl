#!/usr/bin/perl
#
#-------------------------------------------------------------------
#
# Input File Parsing Utilities: Used to query specific variables
# from .ini style configuration files.
#
# $Id: node_types.sh 151 2009-10-20 02:44:48Z karl $
#-------------------------------------------------------------------

use Config::IniFiles;

sub query_global_config_host {

    begin_routine();

    my $host = shift;
    my $logr   = get_logger();

    INFO("   --> Looking for host match...($host)\n");

    foreach(@Clusters) {

	my $loc_cluster = $_;

	if ( ! $global_cfg->SectionExists($loc_cluster) ) {
	    DEBUG("No Input section found for cluster $loc_cluster\n");
	} else {
	    DEBUG("   --> Scanning $loc_cluster \n");
	    my @params = $global_cfg->Parameters($loc_cluster);
	    my $num_params = @params;

	    if ($num_params <= 0 ) {
		DEBUG("No node types defined for cluster $loc_cluster\n");
	    } else {
		foreach(@params) {
		    my $loc_name = $global_cfg->val($loc_cluster,$_);
		    DEBUG("      --> Read $_ = $loc_name\n");
		    if("$host" eq "$loc_name") {
			DEBUG("      --> Found exact match\n");
			$node_cluster = $loc_name;
			$node_type    = $_;
		    }
		    elsif ($host =~ m/$loc_name/ ) {
			DEBUG("      --> Found regex match\n");
			$node_cluster = $loc_name;
			$node_type    = $_;
		    }
		}

	    }
	}
    
    }

    end_routine();

}

sub init_config_file_parsing {

    begin_routine();

    my $infile = shift;
    my $logr   = get_logger();

    INFO("\n** Initializing input config_parsing (file = $infile)\n");
    
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



1;
