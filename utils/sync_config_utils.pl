#!/usr/bin/perl
#-----------------------------------------------------------------------bl-
#--------------------------------------------------------------------------
# 
# LosF - a Linux operating system Framework for HPC clusters
#
# Copyright (C) 2007-2012 Karl W. Schulz
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
# $Id$
#--------------------------------------------------------------------------

use strict;
use OSF_paths;

use File::Basename;
use File::Compare;
use File::Copy;
use File::Path;
use File::stat;
use File::Temp qw(tempfile);
use Term::ANSIColor;

use lib "$osf_log4perl_dir";
use lib "$osf_ini4perl_dir";
use lib "$osf_utils_dir";

use node_types;
use utils;

require "$osf_utils_dir/utils.pl";
require "$osf_utils_dir/parse.pl";
require "$osf_utils_dir/header.pl";
require "$osf_utils_dir/rpm_utils.pl";

BEGIN {

    my $osf_sync_const_file      = 0;
    my $osf_sync_soft_links      = 0;
    my $osf_sync_services        = 0;
    my $osf_sync_permissions     = 0;
    my $osf_sync_os_packages     = 0;
    my $osf_sync_custom_packages = 0;
    
    sub parse_and_sync_const_files {

	verify_sw_dependencies();
	begin_routine();
	
	if ( $osf_sync_const_file == 0 ) {
	    #INFO("** Syncing configuration files (const)\n\n");
	    $osf_sync_const_file = 1;
	}

	(my $node_cluster, my $node_type) = determine_node_membership();
	print "** Syncing configuration files ($node_cluster:$node_type)\n";

	init_local_config_file_parsing("$osf_config_dir/config."."$node_cluster");
	my @sync_files = query_cluster_config_const_sync_files($node_cluster,$node_type);
	my %perm_files = query_cluster_config_sync_permissions($node_cluster,$node_type);

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

    sub parse_and_sync_softlinks {

	verify_sw_dependencies();
	begin_routine();
	
	if ( $osf_sync_soft_links == 0 ) {
	    INFO("** Syncing soft links\n\n");
	    $osf_sync_soft_links = 1;
	}

	(my $node_cluster, my $node_type) = determine_node_membership();

	init_local_config_file_parsing("$osf_config_dir/config."."$node_cluster");

	my %sync_files = query_cluster_config_softlink_sync_files($node_cluster,$node_type);

	while ( my ($key,$value) = each(%sync_files) ) {
	    INFO("   --> $key => $value\n");
	    sync_soft_link_file($key,$value);
	}

	end_routine();
    }

    sub parse_and_sync_services {

	verify_sw_dependencies();
	begin_routine();

	if ( $osf_sync_services == 0 ) {
#	    INFO("\n** Syncing runlevel services\n\n");
	    $osf_sync_services = 1;
	}

	(my $node_cluster, my $node_type) = determine_node_membership();
	print "** Syncing runlevel services ($node_cluster:$node_type)\n";

	init_local_config_file_parsing("$osf_config_dir/config."."$node_cluster");

	# Node type-specific settings: these take precedence over global
	# settings; apply them first

	my %sync_services_custom = query_cluster_config_services($node_cluster,$node_type);

	while ( my ($key,$value) = each(%sync_services_custom) ) {
	    DEBUG("   --> $key => $value\n");
	    sync_chkconfig_services($key,$value);
	}

	# Global chkconfig settings: any node-specific settings
	# applied above are skipped

	my %sync_services = query_cluster_config_services($node_cluster,"LosF-GLOBAL-NODE-TYPE");

	while ( my ($key,$value) = each(%sync_services) ) {
	    DEBUG("   --> $key => $value\n");

	    if ( ! exists $sync_services_custom{$key} ) {
		sync_chkconfig_services($key,$value);
	    }
	}
	
	end_routine();
    }

    sub sync_const_file {

	begin_routine();
	
	my $file       = shift;	# input filename to sync
	my $logr       = get_logger();
	my $found      = 0;
	my $host_name;                       
	my $customized = 0;

	chomp($host_name=`hostname -s`);

	(my $cluster, my $type) = determine_node_membership();
	my %perm_files          = query_cluster_config_sync_permissions($cluster,$type);
	
	if ( ! -s "$file" && ! -l "$file" ) {
	    WARN("   --> Warning: production file $file not found - adding new sync file\n");
	}

	my $basename = basename($file);
	DEBUG("   --> [$basename] Attempting to sync file: $file\n");
	
	# Customization - although we group hosts into specific node
	# types (e.g. logins, computes), we allow for special
	# customization on a host by host based for configuration
	# files.  If a configfile.<hostname> exists, we choose this
	# file to sync in favor of the default configfile.

	my $sync_file = "$osf_top_dir/config/const_files/$cluster/$type/$basename.$host_name";
	DEBUG("   --> Looking for file $sync_file\n");

	if ( ! -s $sync_file ) {
	    $sync_file = "$osf_top_dir/config/const_files/$cluster/$type/$basename";
	    DEBUG("   --> Looking for file $sync_file\n");
	} else {
	    $customized = 1;
	    INFO("  --> Using host specific config file for $host_name\n");
	}
	
	if ( ! -s $sync_file ) {
	    WARN("   --> Warning: config/const_files/$cluster/$type/$basename not " .
		 "found - not syncing...\n");
	    end_routine();
	    return;
	}

	#--------------------------------------
	# Look for file differences and fix 'em
	#--------------------------------------

	# Expand any @losf@ macros

	(my $fh_tmp, my $ref_file) = tempfile();
	    
	expand_text_macros($sync_file,$ref_file,$cluster);
	    
	# Deal with non-symbolic link and diff directly.
	    
	if ( compare($file,$ref_file) == 0 ) {
	    print "   --> "; 
	    print color 'green';
	    print "OK";
	    print color 'reset';
	    print ": $file in sync ";;
	    #print "   --> OK: $file in sync ";
	    if($customized) { 
		print "(using customized config for $host_name)\n";
	    } else { 
		print "\n"; 
	    }
	} else {
	    print "   --> "; 
	    print color 'red';
	    print "FAILED";
	    print color 'reset';
	    print ": [$basename] Differences found: requires syncing";
#	    ERROR("   --> FAILED: [$basename] Differences found: requires syncing ");

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
	    
	    INFO("   --> [$basename] Sync successful\n");
	} # end if difference was found	

	unlink($ref_file);

	# Sync file permission convention: if no additional
	# file-specific file conventions are supplied by the user via
	# the config files, we mirror the permissions of the template
	# config file; otherwise we enforce permissions specified in
	# config file.

	if(defined $perm_files{"$file"}) {
	    if ( -e $file ) {
		my $cmd_string = sprintf("chmod %i %s",$perm_files{"$file"},$file);
		system($cmd_string); 
	    }
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
	    print IN "#--------------------------------------------------------------end-sync-losf-\n";
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
	    print("   --> No losf delimiter present, appending delimiter...\n");
	    return;
	};

	# Check if we have any changes?

	if ( compare($file,$new_file) == 0 ) {
	    print "   --> OK: $file in (partial) sync\n";
	} else {
	    ERROR("   --> FAILED: [$basename] Differences found: $basename requires partial syncing\n");

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

# 	if( $target_parent_dir eq "." && ! -e ) {
# 	    if ( ! -s "$link_parent_dir/$target" ) {
# 		MYERROR("   --> Soft link target is not available ($link_parent_dir/$target)\n");
# 	    }
# 	} else {
# 	    if ( ! -s $target ) {
# 		MYERROR("   --> Soft link target is not available ($target)\n");
# 	    }
# 	}
# 
	if ( ! -s $target ) {
	    if ( ! -s "$link_parent_dir/$target" ) {
		WARN("   --> Soft link target is not available ($target)\n");
		end_routine();
		return;
	    }
	}
	
	INFO("   --> Checking symbolic link\n");
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
       
#	chdir($link_parent_dir) or die "Cannot chdir to $link_parent_dir $!";

	my @ParentDir = split(/\//, $link_parent_dir);
        my $notice_string  = $ParentDir[$#ParentDir]; pop(@ParentDir);
	my $notice_string  = $ParentDir[$#ParentDir]."/$notice_string"; 

	if ( -l $file ) {
	    my $resolved_file = readlink("$file");
	    if ( "$resolved_file" ne "$target" ) {
		ERROR("   --> FAILED [...$notice_string/$basename] Soft link difference found: updating...\n");
		unlink("$file") || MYERROR("[$basename] Unable to remove $file");
		symlink("$target","$file") || 
		    MYERROR("[$notice_string/$basename] Unable to create symlink for $file");	
	    } else {
		print "   --> OK: $file softlink in sync\n";
	    }
	} else {
	    print "  --> FAILED: Creating link between $file -> $target\n";
	    symlink("$target","$file") || 
		MYERROR("[$notice_string/$basename] Unable to create symlink for $file");	
	}

	end_routine();
    }

    sub parse_and_sync_permissions {
	verify_sw_dependencies();
	begin_routine();

	if ( $osf_sync_permissions == 0 ) {
	    INFO("** Syncing file/directory permissions\n\n");
	    $osf_sync_permissions = 1;
	}

	(my $node_cluster, my $node_type) = determine_node_membership();

	init_local_config_file_parsing("$osf_config_dir/config."."$node_cluster");
	my %perm_files = query_cluster_config_sync_permissions($node_cluster,$node_type);

	while ( my ($key,$value) = each(%perm_files) ) {
	    DEBUG("   --> $key => $value\n");

	    if ( -e $key || -d $key ) {
		my $cmd_string = sprintf("chmod %i %s",$value,$key);
		system($cmd_string); 
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

#	my $mode_old = (stat($oldfile))[2] & 0777;
#	my $mode_new = (stat($newfile))[2] & 0777;

	my $st_old = stat($oldfile);
	my $st_new = stat($newfile);

	my $mode_old = $st_old->mode & 0777;
	my $uid_old  = $st_old->uid;
	my $gid_old  = $st_old->gid;

	my $mode_new = $st_new->mode & 0777;
	my $uid_new  = $st_new->uid;
	my $gid_new  = $st_new->gid;

	DEBUG("   --> Desired sync file permission = $mode_old\n");

	if($mode_old != $mode_new) {

	    my $basename = basename($newfile);
	    
	    ERROR("   --> FAILED: [$basename] updating sync file permissions...\n") 
		unless ($display_change_message == 0);

	    chmod ($mode_old, $newfile) || MYERROR ("Unable to chmod permissions for $newfile");
	}

	# make sure ownership is consistent as well

	if ($display_change_message && $uid_old != $uid_new) {
	    ERROR( "   --> FAILED: updating sync file  ownership...\n")
	}
	if ($display_change_message && $gid_old != $gid_new) {
	    ERROR( "   --> FAILED: updating sync group ownership...\n")
	}

	my $cnt = chown $uid_old,$gid_old, $newfile;

	if( $cnt != 1 ) { MYERROR("Unable to chown permissions for $newfile");}

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

	# NOOP if init.d script is not present

	if ( ! -s "/etc/init.d/$service" ) {
		DEBUG("   --> NOOP: $service not installed, ignoring sync request\n");
		return;
	    }

	DEBUG("   --> Desired setting = $enable_service\n");

	# make sure chkconfig is setup - have to read stderr for this one....

 	use IPC::Open3;
 	use File::Spec;
 	use Symbol qw(gensym);
 	open(NULL, ">", File::Spec->devnull);
 	my $pid = open3(gensym, ">&NULL", \*PH, "/sbin/chkconfig --list $service");
 	while( <PH> ) {
	    if ( $_ =~ m/service $service supports chkconfig, but is not referenced/ ) {
		chomp(my $setting=`chkconfig --add $service`);
	    }
	}

 	waitpid($pid, 0);

	chomp(my $setting=`/sbin/chkconfig --list $service`);

	if ( $setting =~ m/3:on/ ) {
	    DEBUG("   --> $service is ON\n");
	    if($enable_service) {
		print "   --> "; 
		print color 'green';
		print "OK";
		print color 'reset';
		print ": $service is ON\n";
#		print "   --> OK: $service is ON\n";
	    } else {
		print "   --> "; 
		print color 'red';
		print "FAILED";
		print color 'reset';
		print ": disabling $service\n";
		`/sbin/chkconfig $service off`;
		`/etc/init.d/$service stop`;
		chomp(my $setting=`/sbin/chkconfig --list $service`);
		if ( $setting =~ m/3:on/ ) {
		    MYERROR("Unable to chkconfig $service off");
		}
	    }
	} elsif ( $setting =~ m/3:off/ ) {
	    DEBUG("   --> $service is OFF\n");
	    if($enable_service) {
		print "   --> "; 
		print color 'red';
		print "FAILED";
		print color 'reset';
		print ": enabling $service\n";
		`/sbin/chkconfig $service on`;
		`/etc/init.d/$service start`;
		chomp(my $setting=`/sbin/chkconfig --list $service`);
		if ( $setting =~ m/3:off/ ) {
		    MYERROR("Unable to chkconfig $service on");
		}
	    } else {
		print "   --> "; 
		print color 'green';
		print "OK";
		print color 'reset';
		print ": $service is OFF\n";
#		print "   --> OK: $service is OFF\n";
	    }
	}

    }

    sub parse_and_sync_os_packages {

	verify_sw_dependencies();
	begin_routine();
	
	if ( $osf_sync_os_packages == 0 ) {
	    $osf_sync_os_packages = 1;
	} else {
	    return;
	}

	(my $node_cluster, my $node_type) = determine_node_membership();
	print "** Syncing OS packages ($node_cluster:$node_type)\n";

	init_local_os_config_file_parsing("$osf_config_dir/os-packages/$node_cluster/packages.config");

	my @os_rpms = query_cluster_config_os_packages($node_cluster,$node_type);

	verify_rpms(@os_rpms);

	end_routine();
    }


    sub parse_and_sync_custom_packages {

	verify_sw_dependencies();
	begin_routine();
	
	if ( $osf_sync_custom_packages == 0 ) {
	    INFO("\n** Syncing Custom packages\n\n");
	    $osf_sync_custom_packages = 1;
	} else {
	    return;
	}

	(my $node_cluster, my $node_type) = determine_node_membership();
	init_local_custom_config_file_parsing("$osf_config_dir/custom-packages/$node_cluster/packages.config");

	my %custom_aliases = ();
	my @custom_rpms    = ();

	INFO("\n");

	# (0) read aliases for later use in custom rpms

	%custom_aliases = query_cluster_config_custom_aliases($node_cluster);
	DEBUG("   --> number of custom aliases defined = ".keys(%custom_aliases)."\n");

	# (1) verify packages for ALL node types

	my $ALL_type = "ALL";

	@custom_rpms = query_cluster_config_custom_packages($node_cluster,$ALL_type);
	foreach my $rpm (@custom_rpms) {
	    DEBUG("   --> Custom rpm for ALL = $rpm\n");
	}

	verify_custom_rpms(\$ALL_type,\@custom_rpms,\%custom_aliases);

	# (2) verify packages for current node types
	
	INFO("\n");

	@custom_rpms = query_cluster_config_custom_packages($node_cluster,$node_type);

	foreach my $rpm (@custom_rpms) {
	    DEBUG("   --> Custom rpm = $rpm\n");
	}

	verify_custom_rpms(\$node_type,\@custom_rpms,\%custom_aliases);

	end_routine();
    }



}

1;

