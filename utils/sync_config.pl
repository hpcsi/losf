#!/usr/bin/perl
#-----------------------------------------------------------------------bl-
#--------------------------------------------------------------------------
# 
# LosF - a Linux operating system Framework for HPC clusters
#
# Copyright (C) 2007,2008,2009,2010 Karl W. Schulz
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
# Utility Functions for syncing small configuration files, 
# symbolic links, and other chkconfig services.
#
# $Id: utils.pl 200 2009-11-01 17:48:31Z karl $
#--------------------------------------------------------------------------

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
parse_and_sync_permissions();

BEGIN {

    my $osf_sync_const_file  = 0;
    my $osf_sync_services    = 0;
    my $osf_sync_permissions = 0;
    
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

	# Now, sync partial contents...

	INFO("** Syncing configuration files (partial contents))\n\n");

	my @partial_files = query_cluster_config_partial_sync_files($node_cluster,$node_type);

	foreach(@partial_files) {
	    sync_partial_file("$_");
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
	    WARN("   --> Warning: config/const_files/$cluster/$type/$basename not " .
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
		MYERROR("   --> Target file $file is not a symlink, aborting...\n");
	    } else {
		my $resolved_file = readlink("$file");
	    
		INFO("   --> Resolved sync file   = $resolved_sync_file\n");
		INFO("   --> Resolved target file = $resolved_file\n");

		if ( "$resolved_sync_file" ne "$resolved_file" ) {
		    ERROR("   --> [$basename] Soft link difference found: updating...\n");
		    unlink("$file") || MYERROR("[$basename] Unable to remove $file");
		    symlink("$resolved_sync_file","$file") || 
			MYERROR("[$basename] Unable to create symlink for $file");
		} else {
		    print "   --> OK: $file softlink in sync\n";
		}
		    
	    }

	} else {

	    # Expand any @losf@ macros

	    (my $fh_tmp, my $ref_file) = tempfile();

	    expand_text_macros($sync_file,$ref_file,$cluster);

	    # Deal with non-symbolic link and diff directly.

	    if ( compare($file,$ref_file) == 0 ) {
		print "   --> OK: $file in sync\n";
	    } else {
		ERROR("   --> [$basename] Differences found: $basename requires syncing\n");

		# Save current copy....

		if ( -e $file ) {
		    my $orig_copy = "/tmp/$basename.orig";
		    print("   --> Copy of original file saved at $orig_copy\n");
		    copy($file,"/tmp/$basename.orig") || MYERROR("Unable to save copy of $basename");
		}
		
		(my $fh, my $tmpfile) = tempfile();
		
		DEBUG("   --> Copying contents to $tmpfile\n");
		
		copy("$ref_file","$tmpfile")  || MYERROR("Unable to copy $sync_file to $tmpfile");
		copy("$tmpfile","$file")      || MYERROR("Unable to move $tmpfile to $file");
#		unlink("$ref_file")           || MYERROR("Unable to remove $ref_file");
		unlink("$tmpfile")            || MYERROR("Unable to remove $tmpfile");

		INFO("   --> [$basename] Sync successful\n");
	    }

	    unlink($ref_file);

	    # Ensure same permissions as original sync file.

	    mirrorPermissions("$sync_file","$file");

	}

	end_routine();
    }


    sub sync_partial_file {

	begin_routine();

	my $file    = shift;
	my $logr    = get_logger();
	my $found   = 0;

	my $file_begin_delim='----------begin-sync-losf-$';
	my $file_end_delim='------------end-sync-losf-$';

	(my $cluster, my $type) = determine_node_membership();
	
	if ( ! -s "$file" && ! -l "$file" ) {
	    WARN("   --> Warning: production file $file not found - adding new sync file\n");
	}

	my $basename = basename($file);
	DEBUG("   --> [$basename] Attempting to partially sync file: $file\n");
	
	my $sync_file = "$osf_top_dir/config/const_files/$cluster/$type/$basename";
	DEBUG("   --> Looking for file $sync_file\n");

	if ( ! -s $sync_file ) {
	    WARN("   --> Warning: config/const_files/$cluster/$type/$basename not " .
		 "found - not syncing...\n");
	    end_routine();
	    return;
	}

	# Expand any @losf@ macros

	(my $fh_tmp, my $ref_file) = tempfile();

	expand_text_macros($sync_file,$ref_file,$cluster);

	# Look for delimiter to define portion of file to sync and embed sync contents

	(my $fh_tmp, my $new_file) = tempfile();

#	print "sync_file = $sync_file\n";
#	print "ref_file  = $ref_file\n";
#	print "new_File  = $new_file\n";

	open(IN,     "<$file")      || die "Cannot open $file\n";
	open(REF,    "<$ref_file")  || die "Cannot open $ref_file\n";
	open(TMPFILE,">$new_file")  || die "Cannot create tmp file $sync_file";

	my $found_delim=0;

	while (<IN>) {	
	    if(/$file_begin_delim/../$file_end_delim/) {
		$found_delim=1;
		if (/--begin-sync-losf-$/) {
		    print TMPFILE "#--------------------------------------------------------------begin-sync-losf-\n";
		    print TMPFILE "#\n";
		    print TMPFILE "# Partially synced file - please do not edit entries between the begin/end\n";
		    print TMPFILE "# sync delimiters or you may lose the contents during the next synchronization \n";
		    print TMPFILE "# process. Knock yourself out adding customizations to the rest of the file as \n";
		    print TMPFILE "# anything outside of the delimited section will be preserved.\n";
		    print TMPFILE "#\n";
		    while (my $line=<REF>) {
			print TMPFILE $line;
		    }
		    print TMPFILE "#--------------------------------------------------------------end-sync-losf-\n";
		}
	    } else {
		print TMPFILE $_;
	    }
	}

	close(TMPFILE);
	close(REF);
	close(IN);

	if ( !$found_delim ) {
	    print("   --> No losf delimiter present, not syncing...\n");
	    return;
	};

	# Check if we have any changes?

	if ( compare($file,$new_file) == 0 ) {
	    print "   --> OK: $file in (partial) sync\n";
	} else {
	    ERROR("   --> [$basename] Differences found: $basename requires partial syncing\n");

	    # Save copy of current file

	    if ( -e $file ) {
		my $orig_copy = "/tmp/$basename.orig";
		print("   --> Copy of original file saved at $orig_copy\n");
		copy($file,"/tmp/$basename.orig") || MYERROR("Unable to save copy of $basename");
	    }

	    # Update production file
		
	    copy("$new_file","$file")     || MYERROR("Unable to move $new_file to $file");

	    INFO("   --> [$basename] Sync successful\n");
	}

	# Ensure same permissions as original sync file.

	mirrorPermissions("$sync_file","$file");

	# Clean up

	unlink $ref_file || die "Cannot clean up $ref_file";
	unlink $new_file || die "Cannot clean up $new_file";

	end_routine();

	return;
    }

    sub parse_and_sync_permissions {
	verify_sw_dependencies();
	begin_routine();

	if ( $osf_sync_permissions == 0 ) {
	    INFO("** Syncing file/directory permissions\n\n");
	    $osf_sync_permissions = 1;
	}

	(my $node_cluster, my $node_type) = determine_node_membership();

	init_local_config_file_parsing("$osf_config_dir/config.sw."."$node_cluster");
	my %perm_files = query_cluster_config_sync_permissions($node_cluster,$node_type);

	while ( my ($key,$value) = each(%perm_files) ) {
	    DEBUG("   --> $key => $value\n");

	    my $cmd_string = sprintf("chmod %i %s",$value,$key);
	    system($cmd_string); 
	}

	end_routine();
	return;
    }

    sub mirrorPermissions {

	begin_routine();

	my $oldfile = shift;
	my $newfile = shift;

	MYERROR("Source and destination files must exist") unless -e $oldfile && -e $newfile;

	my $mode_old = (stat($oldfile))[2] & 0777;
	my $mode_new = (stat($newfile))[2] & 0777;

	DEBUG("   --> Desired sync file permission = $mode_old\n");
	print "   --> FAILED: updating sync file permissions..." unless $mode_old == $mode_new;

	chmod ($mode_old, $newfile) || MYERROR ("Unable to chmod permissions for $newfile");

	end_routine();
	return;
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

