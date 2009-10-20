#!/usr/bin/perl
#
#-------------------------------------------------------------------
#
# Input File Parsing Utilities: Used to query specific variables
# from .ini style configuration files.
#
# $Id: node_types.sh 151 2009-10-20 02:44:48Z karl $
#-------------------------------------------------------------------

#use strict;
#use lib './dependencies/mschilli-log4perl-d124229/lib';
#use lib './dependencies/Config-IniFiles-2.52/lib';

# Global Variables

#my @Clusters;			# Cluster names 
#my $num_clusters;		# Number of clusters to be managed

# BEGIN {

#     eval { require Log::Log4perl; };
    
#     if($@) {
# 	print "\n[Error] The Log4perl module is not available in your local installation.\n";
# 	print   "[Error] Please verify that it built and was installed correctly during the\n";
# 	print   "[Error] configuration process.\n\n";
# 	exit(1);
#     } else {
# 	no warnings;
# 	use Log::Log4perl qw(:easy);
# 	Log::Log4perl->easy_init({level  => $INFO,
# 				  layout => "%m",
# 				  });

# 	my $logr = get_logger();
# 	DEBUG("Log4perl is available\n");
#     }
# }


#init_config_file_parsing("config.machines");

sub init_config_file_parsing {

    use Config::IniFiles;

    begin_routine();

    my $infile = shift;
    my $logr   = get_logger();

    INFO("\n** Initializing input config_parsing (file = $infile)\n");
    
    verify_file_exists($infile);
    
    my $global_cfg = new Config::IniFiles( -file => "$infile" );
#    $global_cfg->OutputConfig;

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

sub verify_file_exists {
    my $filename = shift;

    if ( ! -e $filename ) {
	MYERROR("The following file is not accessible: $filename",
		"Please verify availability.\n");
    }
}

sub MYERROR {

    ERROR("\n");
    foreach (@_) {
	ERROR("[ERROR]: $_\n");
    }
    ERROR("\n");
    exit(1);
}

sub begin_routine {

    my $logr     = get_logger();
    my $routine  = (caller(1))[3];
    my $filename = (caller(1))[1];

    DEBUG("\n<<Starting>> $routine ($filename)\n");
}


sub end_routine {

    my $logr     = get_logger();
    my $routine  = (caller(1))[3];
    my $filename = (caller(1))[1];

    DEBUG("<<Completed>> $routine ($filename)\n\n");
}

1;
