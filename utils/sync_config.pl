#!/usr/bin/perl
#
# $Id: utils.pl 200 2009-11-01 17:48:31Z karl $
#
#-------------------------------------------------------------------
#
# Utility Functions for syncing small configuration files, 
# symbolic links, and other chkconfig services.
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
parse_and_sync_services();

BEGIN {

    my $osf_sync_const_file = 0;
    my $osf_sync_services   = 0;
    
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

    sub parse_and_sync_services {

	verify_sw_dependencies();
	begin_routine();

	if ( $osf_sync_services == 0 ) {
	    INFO("\n** Syncing runlevel services\n\n");
	    $osf_sync_services = 1;
	}

	(my $node_cluster, my $node_type) = determine_node_membership();

	init_local_config_file_parsing("$osf_config_dir/config.sw."."$node_cluster");
	my %sync_services = query_cluster_config_services($node_cluster,$node_type);

	while ( my ($key,$value) = each(%sync_services) ) {
	    DEBUG("   --> $key => $value\n");
	    sync_chkconfig_services($key,$value);
	}
	
	end_routine();
    }

    sub sync_const_file {

	begin_routine();
	
	my $file    = shift;
	my $logr    = get_logger();
	my $found   = 0;

	(my $cluster, my $type) = determine_node_membership();
	
	if ( ! -s "$file" && ! -l "$file" ) {
	    WARN("   --> Warning: production file $file not found - adding new sync file\n");
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

	#--------------------------------------
	# Look for file differences and fix 'em
	#--------------------------------------

	if ( -l $sync_file ) {

	    INFO("   --> Checking symbolic link\n");

	    my $resolved_sync_file = readlink("$sync_file");

	    # Is the target a symlink?

	    if ( ! -l $file ) {
		MYERROR("   --> Target file is not a symlink, aborting...\n");
	    } else {
		my $resolved_file = readlink("$file");
	    
		INFO("   --> Resolved sync file   = $resolved_sync_file\n");
		INFO("   --> Resolved target file = $resolved_file\n");

		if ( "$resolved_sync_file" ne "$resolved_file" ) {
		    ERROR("   --> [$basename] Soft link difference found: updating...\n");
		    unlink("$file") || MYERROR("[$basename] Unable to remove $file");
		    symlink("$resolved_sync_file","$file") || MYERROR("[$basename] Unable to create symlink for $file");
		} else {
		    print "   --> OK: $file softlink in sync\n";
		}
		    
	    }

	} else {

	    # Deal with non-symbolic link and diff directly.
	
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

	}

	end_routine();
    }

    sub sync_chkconfig_services {

	begin_routine();
	
	my $service = shift;
	my $setting = shift;
	my $logr    = get_logger();
	my $found   = 0;

	my $enable_service = 0;

	(my $cluster, my $type) = determine_node_membership();

	INFO("   --> Syncing run-level services for: $service\n");

	if ( "$setting" eq "on" || "$setting" eq "ON" ) {
	    $enable_service = 1;
	} else {
	    $enable_service = 0;
	}

	DEBUG("   --> Desired setting = $enable_service\n");

	chomp(my $setting=`/sbin/chkconfig --list $service`);

	if ( $setting =~ m/3:on/ ) {
	    DEBUG("   --> $service is ON\n");
	    if($enable_service) {
		print "   --> OK: $service is ON\n";
	    } else {
		print "   --> FAILED: disabling $service\n";
		`/sbin/chkconfig $service off`;
		chomp(my $setting=`/sbin/chkconfig --list $service`);
		if ( $setting =~ m/3:on/ ) {
		    MYERROR("Unable to chkconfig $service off");
		}
	    }
	} elsif ( $setting =~ m/3:off/ ) {
	    DEBUG("   --> $service is OFF\n");
	    if($enable_service) {
		print "   --> FAILED: enabling $service\n";
		`/sbin/chkconfig $service on`;
		chomp(my $setting=`/sbin/chkconfig --list $service`);
		if ( $setting =~ m/3:off/ ) {
		    MYERROR("Unable to chkconfig $service on");
		}
	    } else {
		print "   --> OK: $service is OFF\n";
	    }
	}

    }


}

1;

