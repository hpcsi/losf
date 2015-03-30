#!/usr/bin/env perl
#-----------------------------------------------------------------------bl-
#--------------------------------------------------------------------------
# 
# LosF - a Linux operating system Framework for HPC clusters
#
# Copyright (C) 2007-2015 Karl W. Schulz <losf@koomie.com>
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
# Utility functions for syncing small configuration files, 
# symbolic links, and other chkconfig services.
#--------------------------------------------------------------------------

use strict;
use LosF_paths;
use LosF_node_types;
use LosF_utils;

use File::Basename;
use File::Compare;
use File::Copy;
use File::Path;
use File::stat;
use File::Temp qw(tempfile);
use Term::ANSIColor;

use lib "$losf_utils_dir";

require "$losf_utils_dir/utils.pl";
require "$losf_utils_dir/parse.pl";
require "$losf_utils_dir/header.pl";
require "$losf_utils_dir/rpm_utils.pl";

# Global vars to count any detected changes

use vars qw($losf_const_updated       $losf_const_total);
use vars qw($losf_softlinks_updated   $losf_softlinks_total);
use vars qw($losf_services_updated    $losf_services_total);
use vars qw($losf_permissions_updated $losf_permissions_total);

BEGIN {

    my $osf_cached_rpms                 = 0;
    my $osf_sync_const_file             = 0;
    my $osf_sync_soft_links             = 0;
    my $osf_sync_services               = 0;
    my $osf_sync_permissions            = 0;
    my $osf_sync_os_packages            = 0;
    my $osf_sync_os_packages_delete     = 0;
    my $osf_sync_custom_packages        = 0;
    my $osf_sync_custom_packages_delete = 0;
    
    sub parse_and_sync_const_files {
	
	verify_sw_dependencies();
	begin_routine();
	
	my $node_cluster = $main::node_cluster;
	my $node_type    = $main::node_type;

	INFO("** Syncing configuration files ($node_cluster:$node_type)\n");

	init_local_config_file_parsing("$losf_custom_config_dir/config."."$node_cluster");

	my @sync_files    = query_cluster_config_const_sync_files($node_cluster,$node_type);
	my @partial_files = query_cluster_config_partial_sync_files($node_cluster,$node_type);
	my %perm_files    = query_cluster_config_sync_permissions($node_cluster,$node_type);

	# note: if the user supplies a partial config request for a
	# particular appliance, this should override a const file
	# request. We do this to allow a user to have a const file
	# which is completely synced for one node type, but only
	# partially synced for a second node type. Long story short,
	# we now unmark any const files for the host which have the
	# extra partial_file (sacrifice an extra hash for this purpose).

	my %partial_file_hash = ();

	foreach(@partial_files) {
	    $partial_file_hash{$_} = 1;
	}

	# Support for chroot (e.g. alternate provisioning mechanisms).

	my $chroot = "";

	if($LosF_provision::losf_provisioner eq "Warewulf" && requires_chroot_environment() ) {
	    $chroot     = query_warewulf_chroot($node_cluster,$node_type);
	    DEBUG("   --> using alternate chroot for type = $node_type, chroot = $chroot\n");
	}

	foreach(@sync_files) {
	    if( !exists $partial_file_hash{$_} ) {
		sync_const_file($chroot . $_,$node_cluster,$node_type);
	    }
	}

	# Now, sync partial contents...

	INFO("** Syncing partial file contents ($node_cluster:$node_type)\n");
	
	foreach(@partial_files) {
	    sync_partial_file($chroot . $_);
	}

	# Now, verify non-existence of certain files

	INFO("** Syncing non-existence of configuration files ($node_cluster:$node_type)\n");

	my @delete_files = query_cluster_config_delete_sync_files($node_cluster,$node_type);

	foreach(@delete_files) {
	    $losf_const_total++;

	    my $basename = basename("$_");
	    my $file_test = $chroot . $_;

	    if ( -e $file_test ) {
		$losf_const_updated++;
		print_error_in_red("UPDATING");
		ERROR(": [$basename] File present: deleting\n");
		unlink($file_test) || MYERROR("Unable to remove file: $_");
	    } else {
		print_info_in_green("OK");
		INFO(": $chroot$_ not present\n");
	    }
	}
	    
	end_routine();
    }

    sub parse_and_sync_softlinks {

	verify_sw_dependencies();
	begin_routine();
	
	my $node_cluster = $main::node_cluster;
	my $node_type    = $main::node_type;

	INFO("** Syncing soft links ($node_cluster:$node_type)\n");

	init_local_config_file_parsing("$losf_custom_config_dir/config."."$node_cluster");

	# Support for chroot (e.g. alternate provisioning mechanisms).

	my $chroot = "";

	if($LosF_provision::losf_provisioner eq "Warewulf" && requires_chroot_environment() ) {
	    $chroot     = query_warewulf_chroot($node_cluster,$node_type);
	    DEBUG("   --> using alternate chroot for type = $node_type, chroot = $chroot\n");
	}

	my %sync_files = query_cluster_config_softlink_sync_files($node_cluster,$node_type);

	while ( my ($key,$value) = each(%sync_files) ) {
	    TRACE("   --> $chroot$key => $chroot$value\n");
	    sync_soft_link_file($chroot.$key,$chroot.$value);
	}

	# Global soft link settings; any node-specific settings
	# applied above are skipped

	my %sync_files_global = query_cluster_config_softlink_sync_files($node_cluster,"LosF-GLOBAL-NODE-TYPE");

	while ( my ($key,$value) = each(%sync_files_global) ) {
	    TRACE("   --> $chroot$key => $chroot$value\n");
	    if ( ! exists $sync_files{$key} ) {
		sync_soft_link_file($chroot.$key,$chroot.$value);
	    }
	}

	end_routine();
    }

    sub parse_and_sync_services {

	verify_sw_dependencies();
	begin_routine();

	my $node_cluster = $main::node_cluster;
	my $node_type    = $main::node_type;

	INFO("** Syncing runlevel services ($node_cluster:$node_type)\n");

	init_local_config_file_parsing("$losf_custom_config_dir/config."."$node_cluster");

	# Node type-specific settings: these take precedence over global
	# settings; apply them first

	my %sync_services_custom = query_cluster_config_services($node_cluster,$node_type);

	while ( my ($key,$value) = each(%sync_services_custom) ) {
	    TRACE("   --> $key => $value\n");
	    sync_chkconfig_services($key,$value);
	}

	# Global chkconfig settings: any node-specific settings
	# applied above are skipped

	my %sync_services = query_cluster_config_services($node_cluster,"LosF-GLOBAL-NODE-TYPE");

	while ( my ($key,$value) = each(%sync_services) ) {
	    TRACE("   --> $key => $value\n");

	    if ( ! exists $sync_services_custom{$key} ) {
		sync_chkconfig_services($key,$value);
	    }
	}
	
	end_routine();
    }

    sub sync_const_file {

	begin_routine();

	my $file       = shift;	# input filename to sync
	my $cluster    = shift;	# cluster name
	my $type       = shift;	# node type

	my $logr       = get_logger();
	my $found      = 0;
	my $customized = 0;

        my ($host_name,$doman_name) = query_local_network_name();

	my %perm_files  = query_cluster_config_sync_permissions($cluster,$type);
	
	if ( ! -s "$file" && ! -l "$file" ) {
	    DEBUG("   --> Warning: production file $file not found - adding new sync file\n");
	}

	my $basename = basename($file);
	DEBUG("   --> [$basename] Attempting to sync file: $file\n");
	
	# Customization - although we group hosts into specific node
	# types (e.g. logins, computes), we allow for special
	# customization on a host by host basis for configuration
	# files.  If a configfile.<hostname> exists, we choose this
	# file to sync in favor of the default configfile.

	my $sync_file = "$losf_custom_config_dir/const_files/$cluster/$type/$basename.$host_name";
	DEBUG("   --> Looking for file $sync_file\n");

	if ( ! -e $sync_file ) {
	    $sync_file = "$losf_custom_config_dir/const_files/$cluster/$type/$basename";
	    DEBUG("   --> Looking for file $sync_file\n");
	} else {
	    $customized = 1;
	    INFO("  --> Using host specific config file for $host_name\n");
	}
	
	if ( ! -e $sync_file ) {
	    DEBUG("   --> Warning: config/const_files/$cluster/$type/$basename not " .
		 "found - not syncing...\n");
	    end_routine();
	    return;
	}

	$losf_const_total++;

	#--------------------------------------
	# Look for file differences and fix 'em
	#--------------------------------------

	# Expand any @losf@ macros

	(my $fh_tmp, my $ref_file) = tempfile();
	    
	expand_text_macros($sync_file,$ref_file,$cluster);
	    
	# Deal with non-symbolic link and diff directly.

	if ( compare($file,$ref_file) == 0 ) {
	    print_info_in_green("OK");
	    INFO(": $file in sync ");
	    if($customized) { 
		INFO("(using customized config for $host_name)\n");
	    } else { 
		INFO("\n"); 
	    }
	} else {
	    $losf_const_updated++;
	    print_error_in_red("UPDATING");
	    ERROR(": [$basename] Differences found: requires syncing");

	    if($customized) { 
		print "(using custom config for $host_name)\n";
	    } else { 
		print "\n"; 
	    }

	    # Save current copy. We save a copy for admin convenience in /tmp/losf. 

	    my $save_dir = "/tmp/losf";

	    if ( ! -d $save_dir ) {
		INFO("Creating $save_dir directory to store orig file during syncing\n");
		mkdir($save_dir,0700)
	    }
	    
	    if ( -e $file ) {
		my $orig_copy = "$save_dir/$basename.orig";
		
		if ( "$basename" ne "shadow" || "$basename" ne "passwd" || "$basename" ne "group" ) {
		    print "       --> Copy of original file saved at $orig_copy\n";
		    copy($file,"$save_dir/$basename.orig") || MYERROR("Unable to save copy of $basename");
		    mirrorPermissions("$file","$save_dir/$basename.orig");
		}
	    }
	    
	    # Make sure path to file exits;
	    
	    my $parent_dir = dirname($file);

	    if ( ! -d $parent_dir ) {
		mkpath("$parent_dir") || MYERROR("Unable to create path $parent_dir");
	    }
	    
	    my $tmpfile = "$file"."__losf__new";

	    DEBUG("   --> Copying contents to $tmpfile\n");

	    copy("$ref_file","$tmpfile")  || MYERROR("Unable to copy $sync_file to $tmpfile");

	    MYERROR("Unable to copy temp file to desired volume ($tmpfile)") unless -s $tmpfile;

	    # Unix-safe way to update
	    
	    rename ($tmpfile,$file)       || MYERROR("Unable to rename $tmpfile -> $file");

	    mirrorPermissions("$sync_file","$file",0);
	    
	    INFO("      --> [$basename] Sync successful\n");
	} # end if difference was found	

	unlink($ref_file);

	# Sync file permission convention: if no additional
	# file-specific file conventions are supplied by the user via
	# the config files, we mirror the permissions of the template
	# config file; otherwise the permissions will be set in
	# subsequent call to parse_and_sync_permissions().


	if(defined $perm_files{"$file"}) {
	    DEBUG("   --> skipping mirrorPermisisons - specific user permissions provided\n");
	} else {
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
	
	my $sync_file = "$losf_custom_config_dir/const_files/$cluster/$type/$basename";
	DEBUG("   --> Looking for file $sync_file\n");

	if ( ! -s $sync_file ) {
	    DEBUG("   --> Warning: config/const_files/$cluster/$type/$basename not " .
		 "found - not syncing...\n");
	    end_routine();
	    return;
	}

	# Expand any @losf@ macros

	(my $fh_tmp, my $ref_file) = tempfile();

	expand_text_macros($sync_file,$ref_file,$cluster);

	# Look for delimiter to define portion of file to sync and embed sync contents

	(my $fh_tmp, my $new_file) = tempfile();

	# 

	if ( ! -e "$file" ) {
	    DEBUG("   --> Warning: partial const_file $file not present, ignoring sync request\n");
	    return 0;
	}

	open(IN,     "+<$file")     || die "Cannot open $file\n";
	open(REF,    "<$ref_file")  || die "Cannot open $ref_file\n";
	open(TMPFILE,">$new_file")  || die "Cannot create tmp file $sync_file";

	# Verify that the delimter is present; add it if not.

 	my $found_delim=0;
 
 	while(<IN>) {
 	    if(/$file_begin_delim/../$file_end_delim/) {
 		$found_delim=1;
 	    }
 	}
 
	if ( !$found_delim ) {
	    print("   --> INFO: Adding partial sync delimiter to file $file\n");
	    print IN "#--------------------------------------------------------------begin-sync-losf-\n";
	    print IN "#----------------------------------------------------------------end-sync-losf-\n";
	};

	seek(IN, 0, 0)  || MYERROR("can't rewind numfile: $!");
	$found_delim = 0;

	while (<IN>) {	
	    if(/$file_begin_delim/../$file_end_delim/) {
		$found_delim=1;
		if (/--begin-sync-losf-$/) {
		    print TMPFILE "#--------------------------------------------------------------begin-sync-losf-\n";
		    print TMPFILE "#\n";
		    print TMPFILE "# LosF Partially synced file - please do not edit entries between the begin/end\n";
		    print TMPFILE "# sync delimiters or you may lose the contents during the next synchronization \n";
		    print TMPFILE "# process. Knock yourself out adding customizations to the rest of the file as \n";
		    print TMPFILE "# anything outside of the delimited section will be preserved.\n";
		    print TMPFILE "#\n";
		    while (my $line=<REF>) {
			print TMPFILE $line;
		    }
		    print TMPFILE "#----------------------------------------------------------------end-sync-losf-\n";
		}
	    } else {
		print TMPFILE $_;
	    }
	}

	close(TMPFILE);
	close(REF);
	close(IN);

	if ( !$found_delim ) {
	    print("   --> No losf delimiter present, appending delimiter...\n");
	    return;
	};

	# Check if we have any changes?

	if ( compare($file,$new_file) == 0 ) {
	    print_info_in_green("OK");
	    INFO(": $file in (partial) sync\n");
	} else {
	    $losf_const_updated++;
	    print_error_in_red("UPDATING");
	    ERROR(": [$basename] Differences found: $basename requires partial syncing\n");

	    # Save current copy. We save a copy for admin convenience in /tmp/losf. 

	    my $save_dir = "/tmp/losf";

	    if ( ! -d $save_dir ) {
		INFO("Creating $save_dir directory to store orig file during syncing\n");
		mkdir($save_dir,0700)
	    }

	    if ( -e $file ) {
		my $orig_copy = "$save_dir/$basename.orig";
		print "       --> Copy of original file saved at $orig_copy\n";
		copy($file,"$save_dir/$basename.orig") || MYERROR("Unable to save copy of $basename");
	    }

	    # Update production file
		
	    copy("$new_file","$file")     || MYERROR("Unable to move $new_file to $file");
	    mirrorPermissions("$sync_file","$file",0);

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

    sub sync_soft_link_file {

	begin_routine();
	
	my $file    = shift;
	my $target  = shift;
	my $logr    = get_logger();

	(my $cluster, my $type) = determine_node_membership();

	my $link_parent_dir   = dirname($file);
	my $target_parent_dir = dirname($target);

	if ( ! -s $target ) {
	    if ( ! -s "$link_parent_dir/$target" ) {
		print_debug_in_yellow("WARN:");
		DEBUG("Soft link target is not available ($target)\n");
		end_routine();
		return;
	    }
	}

	$losf_softlinks_total++;
	
	TRACE("   --> Checking symbolic link\n");
	my $basename = basename($file);

	if( -e $file && ! -l $file ) {
	    WARN("   --> Desired soft link exists as a file, removing existing file\n");
	    unlink("$file") || MYERROR("[$basename] Unable to remove $file");
	}

	if ( -d $link_parent_dir) {
	    chdir($link_parent_dir);
	} else {
	    WARN("   --> Parent directory for soft link is not available ($link_parent_dir)\n");
	    end_routine();
	    return;
	}
       
	my @ParentDir = split(/\//, $link_parent_dir);
        my $notice_string  = $ParentDir[$#ParentDir]; pop(@ParentDir);
	my $notice_string  = $ParentDir[$#ParentDir]."/$notice_string"; 

	if ( -l $file ) {
	    my $resolved_file = readlink("$file");
	    if ( "$resolved_file" ne "$target" ) {
		$losf_softlinks_updated++;
		ERROR("   --> UPDATING [...$notice_string/$basename] Soft link difference found: updating...\n");
		unlink("$file") || MYERROR("[$basename] Unable to remove $file");
		symlink("$target","$file") || 
		    MYERROR("[$notice_string/$basename] Unable to create symlink for $file");	
	    } else {
		print_info_in_green("OK");
		INFO(": $file softlink in sync\n");
	    }
	} else {
	    $losf_softlinks_updated++;
	    print_error_in_red("UPDATING");
	    ERROR(": Creating link between $file -> $target\n");
	    symlink("$target","$file") || 
		MYERROR("[$notice_string/$basename] Unable to create symlink for $file");	
	}

	end_routine();
    }

    sub sync_perm_file {
	verify_sw_dependencies();
	begin_routine();

        my $key   = shift;
        my $value = shift;

        my $parent_dir = dirname($key);

        # Check on existence of user-desired directory.
        # Directories are designated via the presence of a
        # trailing /
        
        if( $key =~ /(.*)\/$/) {
            if( -d $key) {
		    print_info_in_green("OK");
		    INFO(": $key directory present\n");
            } else {
                $losf_permissions_updated++;
                print_error_in_red("UPDATING");
                ERROR(": Desired directory $key does not exist...creating\n");
                mkpath("$key") || MYERROR("Unable to create path $key");
                my $cmd_string = sprintf("chmod %i %s",$value,$key);
                system($cmd_string); 
            }
        }

        if ( -e $key || -d $key ) {
		my $info = stat($key);
		my $current_mode = $info->mode;
                
		my $current_mode = sprintf("%4o",$current_mode & 07777);
                
		if($current_mode == $value) {
		    print_info_in_green("OK");
		    INFO(": $key perms correct ($value)\n");
		} else {
		    $losf_permissions_updated++;
		    print_error_in_red("UPDATING");
		    ERROR(": $key perms incorrect..setting to $value\n");
                    
		    my $cmd_string = sprintf("chmod %i %s",$value,$key);
		    system($cmd_string); 
		}
        }

	end_routine();
    } # end sub sync_perm_file()

    sub parse_and_sync_permissions {
	verify_sw_dependencies();
	begin_routine();

	my $node_cluster = $main::node_cluster;
	my $node_type    = $main::node_type;

	INFO("** Syncing file/directory permissions ($node_cluster:$node_type)\n");

	init_local_config_file_parsing("$losf_custom_config_dir/config."."$node_cluster");

	# Support for chroot (e.g. alternate provisioning mechanisms).

	my $chroot = "";

	if($LosF_provision::losf_provisioner eq "Warewulf" && requires_chroot_environment() ) {
	    $chroot = query_warewulf_chroot($node_cluster,$node_type);
	    DEBUG("   --> using alternate chroot for type = $node_type, chroot = $chroot\n");

            # chroot does not include trailing slash, add it in locally
            if($chroot ne "") {
                $chroot = $chroot . "/";
            }
	}

	# Node type-specific settings: these take precedence over global
	# settings; apply them first

	my %perm_files_custom = query_cluster_config_sync_permissions($node_cluster,$node_type);

	$losf_permissions_total = scalar keys %perm_files_custom;

	while ( my ($key_path ,$value) = each(%perm_files_custom) ) {
	    my $key = $chroot . $key_path;
	    TRACE("   --> $key => $value\n");
            sync_perm_file($key,$value);
        }

        # Global perm settings; any node-type specific settings applied above are skipped

	my %perm_files = query_cluster_config_sync_permissions($node_cluster,"LosF-GLOBAL-NODE-TYPE");

	while ( my ($key_path ,$value) = each(%perm_files) ) {
            my $key = $chroot . $key_path;
	    TRACE("   --> $key => $value\n");

	    if ( ! exists $perm_files_custom{$key} ) {
                $losf_permissions_total++;
                sync_perm_file($key,$value);
            }
        }

	end_routine();
	return;
    }

    sub mirrorPermissions {

	begin_routine();

	my $oldfile = shift;
	my $newfile = shift;

	# default is to show permissions change message; in certain cases when updating a file, we know that 
	# the perms are going to change and allow this subroutine to be called with an optional 3rd argument
	# to override the default message display

	my $display_change_message = 1; # default to perm change message

	if( @_ >= 1 ) {
	    $display_change_message = shift;
	}

	MYERROR("Source and destination files must exist") unless -e $oldfile && -e $newfile;

	my $st_old = stat($oldfile);
	my $st_new = stat($newfile);

	my $mode_old = $st_old->mode & 0777;
	my $uid_old  = $st_old->uid;
	my $gid_old  = $st_old->gid;

	my $mode_new = $st_new->mode & 0777;
	my $uid_new  = $st_new->uid;
	my $gid_new  = $st_new->gid;

	DEBUG("   --> Desired sync file permission = $mode_old\n");

	# init flag to track any perm/ownership changes. We count any of the
	# following as a single change wrt to the update display_changes tally.

	my $localChange = 0;
	my $basename = basename($newfile);

	if($mode_old != $mode_new) {

	    if ( $display_change_message != 0) {
		print_error_in_red("UPDATING");
		ERROR(": [$basename] updating sync file permissions...\n");
	    }

	    chmod ($mode_old, $newfile) || MYERROR ("Unable to chmod permissions for $newfile");
	    if($localChange == 0) {$localChange = 1;}
	    
	}

	# make sure ownership is consistent as well

	if ($display_change_message && $uid_old != $uid_new) {
	    print_error_in_red("UPDATING");
	    ERROR(": [$basename] updating file  ownership...\n");
	    if($localChange == 0) {$localChange = 1;}
	}

	if ($display_change_message && $gid_old != $gid_new) {
	    print_error_in_red("UPDATING");
	    ERROR(": [$basename] updating group ownership...\n");
	    if($localChange == 0) {$localChange = 1;}
	}

	my $cnt = chown $uid_old,$gid_old, $newfile;

	if( $cnt != 1 ) { MYERROR("Unable to chown permissions for $newfile");}

	if($localChange == 1) {$losf_const_updated++;}

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

	my $cluster    = $main::node_cluster;
	my $type       = $main::node_type;
	my $chrootFlag = 0;

	DEBUG("   --> Syncing run-level services for: $service\n");

	if ( "$setting" eq "on" || "$setting" eq "ON" ) {
	    $enable_service = 1;
	} else {
	    $enable_service = 0;
	}

	# Support for chroot (e.g. alternate provisioning mechanisms).

	my $chroot = "/";

	if($LosF_provision::losf_provisioner eq "Warewulf" && requires_chroot_environment() ) {
	    $chroot     = query_warewulf_chroot($cluster,$type);
	    $chrootFlag = 1;
	    DEBUG("   --> using alternate chroot for type = $type, chroot = $chroot\n");
	}
	    
	# NOOP if init.d script is not present
	
	if ( ! -s "$chroot/etc/init.d/$service" ) {
	    TRACE("   --> NOOP: $service not installed, ignoring sync request\n");
	    return;
	}
	
	$losf_services_total++;
	
	DEBUG("   --> Desired setting = $enable_service\n");
	
	my $setting = `chroot $chroot /sbin/chkconfig --list $service 2>&1`;
	
	# make sure chkconfig is setup - have to check stderr for this one....
	
	if ( $setting =~ m/service $service supports chkconfig, but is not referenced/ ) {
	    `chroot $chroot /sbin/chkconfig --add $service`;
	    $setting = `chroot $chroot /sbin/chkconfig --list $service 2>&1`;
	}
	
	chomp($setting);
	
	if ( $setting =~ m/3:on/ ) {
	    DEBUG("   --> $service is ON\n");
	    if($enable_service) {
		print_info_in_green("OK");
		INFO( ": $service is ON\n");
	    } else {
		$losf_services_updated++;
		print_error_in_red("UPDATING");
		ERROR( ": disabling $service\n");
		`chroot $chroot /sbin/chkconfig $service off`;
		if($chrootFlag == 0) {
		    `chroot $chroot /etc/init.d/$service stop`;
		    chomp(my $setting=`chroot $chroot /sbin/chkconfig --list $service`);
		    if ( $setting =~ m/3:on/ ) {
			MYERROR("Unable to chkconfig $service off");
		    }
		}
	    }
	} elsif ( $setting =~ m/3:off/ ) {
	    DEBUG("   --> $service is OFF\n");
	    if($enable_service) {
		$losf_services_updated++;
		print_error_in_red("UPDATING");
		ERROR(": enabling $service\n");
		`chroot $chroot /sbin/chkconfig $service on`;
		if($chrootFlag == 0) {
		    `chroot $chroot /etc/init.d/$service start`;
		    chomp(my $setting=`chroot $chroot /sbin/chkconfig --list $service`);
		    if ( $setting =~ m/3:off/ ) {
			MYERROR("Unable to chkconfig $service on");
		    }
		}
	    } else {
		print_info_in_green("OK");
		INFO (": $service is OFF\n");
	    }
	}
	
    }

    sub parse_and_uninstall_os_packages {

	verify_sw_dependencies();
	begin_routine();

	my $node_cluster = $main::node_cluster;
	my $node_type    = $main::node_type;

	INFO("** Checking on OS packages to remove ($node_cluster:$node_type)\n");

	init_local_os_config_file_parsing("$losf_custom_config_dir/os-packages/$node_cluster/packages.config");

	# verify that certain packages are *not* installed

	my @os_rpms_remove = query_cluster_config_os_packages_remove($node_cluster,$node_type);

	verify_rpms_removed(@os_rpms_remove);

	end_routine();
    }

    sub parse_and_sync_os_packages {

	verify_sw_dependencies();
	begin_routine();
	
	INFO("** Syncing OS packages ($main::node_cluster:$main::node_type)\n");

	init_local_os_config_file_parsing("$losf_custom_config_dir/os-packages/$main::node_cluster/packages.config");

	# now, verify that all desired os packages are installed

	my @os_rpms = query_cluster_config_os_packages($main::node_cluster,$main::node_type);

	verify_rpms(@os_rpms);

	end_routine();
    }

    sub parse_and_uninstall_custom_packages {
	verify_sw_dependencies();
	begin_routine();

	my $node_cluster = $main::node_cluster;
	my $node_type    = $main::node_type;

	init_local_custom_config_file_parsing("$losf_custom_config_dir/custom-packages/$node_cluster/packages.config");

	INFO("** Checking on Custom packages to remove ($node_cluster:$node_type)\n");

	my %custom_aliases = ();
	my @custom_rpms    = ();

	# (0) read aliases for later use in custom rpms

	%custom_aliases = query_cluster_config_custom_aliases($node_cluster);
	DEBUG("   --> number of custom aliases defined = ".keys(%custom_aliases)."\n");

	my $ALL_type = "ALL";

	# verify *non* existence of desired packages for ALL node types

	my @custom_rpms_remove = query_cluster_config_custom_packages_remove($node_cluster,$ALL_type);
	foreach my $rpm (@custom_rpms_remove) {
	    DEBUG("   --> Custom rpm removal requested for ALL = $rpm\n");
	}

	verify_custom_rpms_removed(\$ALL_type,\@custom_rpms_remove,\%custom_aliases);

	# verify *non* existence of desired packages current  node type

	my @custom_rpms_remove = query_cluster_config_custom_packages_remove($node_cluster,$node_type);
	foreach my $rpm (@custom_rpms_remove) {
	    DEBUG("   --> Custom rpm removal requested for node:$node_type = $rpm\n");
	}

	verify_custom_rpms_removed(\$node_type,\@custom_rpms_remove,\%custom_aliases);

	end_routine();
    }

    sub parse_and_sync_custom_packages {

	verify_sw_dependencies();
	begin_routine();

	my $node_cluster = $main::node_cluster;
	my $node_type    = $main::node_type;
	
        INFO("** Syncing Custom packages ($node_cluster:$node_type)\n");

	init_local_custom_config_file_parsing("$losf_custom_config_dir/custom-packages/$node_cluster/packages.config");

	my %custom_aliases = ();
	my @custom_rpms    = ();

	# (0) read aliases for later use in custom rpms

	%custom_aliases = query_cluster_config_custom_aliases($node_cluster);
	DEBUG("   --> number of custom aliases defined = ".keys(%custom_aliases)."\n");

	my $ALL_type = "ALL";

	# verify packages for ALL node types

	@custom_rpms = query_cluster_config_custom_packages($node_cluster,$ALL_type);
	foreach my $rpm (@custom_rpms) {
	    DEBUG("   --> Custom rpm for ALL = $rpm\n");
	}

	verify_custom_rpms(\$ALL_type,\@custom_rpms,\%custom_aliases);

	# verify packages for current node types
	
	@custom_rpms = query_cluster_config_custom_packages($node_cluster,$node_type);

	foreach my $rpm (@custom_rpms) {
	    DEBUG("   --> Custom rpm = $rpm\n");
	}

	verify_custom_rpms(\$node_type,\@custom_rpms,\%custom_aliases);

	end_routine();
    }

}

sub print_error_in_red {
    my $text = shift;

    ERROR( "   --> ");     
    print color 'red';
    ERROR($text);
    print color 'reset';
    return;
}

sub print_info_in_green {
    my $text = shift;

    INFO( "   --> ");     
    print color 'green';
    INFO($text);
    print color 'reset';
    return;
}

sub print_warn_in_yellow {
    my $text = shift;
    WARN( "   --> ");     
    print color 'yellow';
    WARN($text);
    print color 'reset';
    return;
}

sub print_debug_in_yellow {
    my $text = shift;
    DEBUG( "   --> ");     
    print color 'yellow';
    DEBUG($text);
    print color 'reset';
    return;
}

1;

