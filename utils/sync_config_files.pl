#!/usr/bin/perl
#
# $Id: utils.pl 200 2009-11-01 17:48:31Z karl $
#
#-------------------------------------------------------------------
#
# Utility Functions for Syncing Small Configuration Files
#
# $Id: utils.pl 200 2009-11-01 17:48:31Z karl $
#-------------------------------------------------------------------

use strict;
use OSF_paths;

use File::Basename;
use File::Compare;
use File::Copy;
use File::Temp qw(tempfile);

use lib "$osf_log4perl_dir";
use lib "$osf_ini4perl_dir";
use lib "$osf_utils_dir";

use node_types;
use utils;

require "$osf_utils_dir/utils.pl";
require "$osf_utils_dir/parse.pl";
require "$osf_utils_dir/header.pl";

parse_and_sync_const_files();

BEGIN {

    my $osf_sync_const_file = 0;
    
    sub parse_and_sync_const_files {

	verify_sw_dependencies();
	begin_routine();

	if ( $osf_sync_const_file == 0 ) {
	    INFO("** Syncing configuration files (const)\n\n");
	    $osf_sync_const_file = 1;
	}

	(my $node_cluster, my $node_type) = determine_node_membership();

	init_local_config_file_parsing("$osf_config_dir/config.sw."."$node_cluster");
	my @sync_files = query_cluster_config_const_sync_files($node_cluster,$node_type);

	foreach(@sync_files) {
	    sync_const_file("$_");
	}
	
	end_routine();
    }

    sub sync_const_file {

	begin_routine();
	
	my $file    = shift;
	my $logr    = get_logger();
	my $found   = 0;

	(my $cluster, my $type) = determine_node_membership();
	
	if ( ! -s "$file" ) {
	    WARN("   --> Warning: production file $file not found - not syncing file\n");
	    end_routine();
	    return;
	}
	
	my $basename = basename($file);
	DEBUG("   --> [$basename] Attempting to sync file: $file\n");
	
	my $sync_file = "$osf_top_dir/config/const_files/$cluster/$type/$basename";
	DEBUG("   --> Looking for file $sync_file\n");
	
	if ( ! -s $sync_file ) {
	    ERROR("   --> Warning: config/const_files/$cluster/$type/$basename not " .
		 "found - not syncing...\n");
	    end_routine();
	    return;
	}
	
	if ( compare($file,$sync_file) == 0 ) {
	    print "   --> OK: $file in sync\n";
	} else {
	    ERROR("   --> [$basename] Differences found: $basename requires syncing\n");
	    
	    (my $fh, my $tmpfile) = tempfile();
	    
	    DEBUG("   --> Copying contents to $tmpfile\n");
	    
	    copy("$sync_file","$tmpfile") || MYERROR("Unable to copy $sync_file to $tmpfile");
	    copy("$tmpfile","$file")      || MYERROR("Unable to move $tmpfile to $file");
	    unlink("$tmpfile")            || MYERROR("Unable to remove $tmpfile");
	    
	    INFO("   --> [$basename] Sync successful\n");
	}

	end_routine();
    }

}

1;

