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
		if($loc_domain eq $domain) {
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
	print "\n";
	print "Cluster   = $node_cluster\n";
	print "Node_Type = $node_type\n";
	print "\n";
pn
    }

    return ($node_cluster,$node_type);
    end_routine();
}

sub init_config_file_parsing {
    use File::Basename;

    begin_routine();

    my $infile    = shift;
    my $logr      = get_logger();
    my $shortname = fileparse($infile);

    INFO("\n** Initializing input config_parsing ($shortname)\n");
    
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
