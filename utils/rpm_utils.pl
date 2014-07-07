#!/usr/bin/env perl
#-----------------------------------------------------------------------bl-
#--------------------------------------------------------------------------
# 
# LosF - a Linux operating system Framework for HPC clusters
#
# Copyright (C) 2007-2014 Karl W. Schulz <losf@koomie.com>
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
# Utility Functions
#--------------------------------------------------------------------------

use LosF_paths;
use LosF_rpm_topdir;

use Sys::Syslog;  
use Digest::MD5;
use Env qw(SRC_DIR MODE);
use Term::ANSIColor;

# --------------------------------------------------------
# verify_rpms (rpms)
# 
# Checks to see if input list of Distro rpms versions are
# installed; if not, installs desires packages.
# --------------------------------------------------------

sub verify_rpms {
    begin_routine();

    my @rpm_list        = @_;
    my @rpms_to_install = ();
    my $num_rpms        = @rpm_list;

    $losf_os_packages_total = $num_rpms;

    if($num_rpms < 1) { return; }

    DEBUG("   --> Verifying desired OS RPMs are installed ($num_rpms total)...\n");

    foreach $entry (@rpm_list) {

	my @rpm_array  = split(/\s+/,$entry);
	my $rpm = $rpm_array[0];

	DEBUG("   --> Checking $rpm\n");

	# Determine desired rpm versionioning from options in config file; 

	my $desired_version = "";
	my $desired_release = "";
	my $desired_arch    = "";

	shift @rpm_array;
	my $num_options = @rpm_array;

	foreach $option (@rpm_array) {
	    DEBUG("       --> Option = $option\n");
	    if( $option =~ m/version=(\S+)/ ) { 
		$desired_version = $1;
		DEBUG("            --> found version = $1\n");
	    } elsif ( $option =~ m/release=(\S+)/ ) { 
		$desired_release = $1;
		DEBUG("            --> found release = $1\n");
	    } elsif ( $option =~ m/arch=(\S+)/ ) { 
		$desired_arch = $1;
		DEBUG("            --> found arch = $1\n");
	    }
	}

	# Feb 2013: New config requirement with version 0.41 

	if( $desired_version eq "" || $desired_release eq "" || $desired_arch eq "" ) {
	    ERROR("\n");
	    ERROR("[ERROR]: Configuration error detected:\n");
	    ERROR("[ERROR]: --> $entry\n");
	    ERROR("\n");
	    ERROR("[ERROR]: As of LosF v. 0.41, OS package definitions must include specific version, release and\n");
	    ERROR("[ERROR]: arch options for each desired package. \"losf addpkg\" will automatically include these\n");
	    ERROR("[ERROR]: options for new additions, but config files from earlier versions need to be upgraded.\n");
	    ERROR("[ERROR]: for compatability\n");
	    ERROR("\n");
	    ERROR("[ERROR]: Consider running \"losf config-upgrade\" to update your local copy to the latest\n");
	    ERROR("[ERROR]: configuration format.\n");
	    exit (1);
	}

	my $full_rpm_name = "$rpm-$desired_version-$desired_release.$desired_arch";
	    
	# Installing from path provided by user on command-line?

	my $filename = "";
###	my $arch     = rpm_arch_from_filename($rpm);

	if ( "$MODE" eq "PXE" ) {
	    $filename = "$SRC_DIR/$desired_arch/$full_rpm_name.rpm";
	} else {
	    $filename = "$rpm_topdir/$desired_arch/$full_rpm_name.rpm";
	}

	# Pull down RPM if not cached locally

	if ( ! -s "$filename") {
	    my $cmd="yumdownloader -q --destdir=$rpm_topdir/$desired_arch $full_rpm_name";
	    INFO("   --> Downloading OS rpm -> $full_rpm_name\n");
	    system($cmd);
	}

	if ( ! -s "$filename" ) {
	    MYERROR("Unable to locate local OS rpm-> $filename\n");
	}

	# 10/5/12 - give preferential treatment to cache directory. If
	# the file is present in the cache, we try to use
	# it. Otherwise, we revert to the standard rpm_topdir.

	if( $rpm_cachedir ne "NONE" ) {
	    my $cache_file = "$rpm_cachedir/$arch/$full_rpm_name.rpm";
	    if ( -s $cache_file ) {
		DEBUG("Using cached rpm in $cache_file");
		$filename=$cache_file;
	    }
	}

	# return array format = (name,version,release,arch)

	my @installed_rpm = is_os_rpm_installed("$rpm.$desired_arch");

	if (@installed_rpm > 1) {
	    if ($rpm eq "kernel" ) {
		print "HACK - ignoring multiply installed kernel RPMs for the time being - need to fix OSSs\n";
		next;
	    } 
	    if ($rpm eq "kernel-headers" ) {
		print "HACK - ignoring multiply installed kernel-headers RPMs for the time being - need to fix OSSs\n";
		next;
	    } 
	    if ($rpm eq "kernel-devel" ) {
		print "HACK - ignoring multiply installed kernel-devel RPMs for the time being - need to fix OSSs\n";
		next;
	    } 
	    MYERROR("Multiple OS package versions detected ($rpm). Invalid configuration.\n");
	}

	my @installed  = split(' ',$installed_rpm[0]);

	if( @installed_rpm == 0 ) {
	    DEBUG("   --> $rpm is not installed - registering for add...\n");
	    SYSLOG("Registering previously uninstalled $full_rpm_name for update");
	    push(@rpms_to_install,$filename);
	} elsif( "$desired_version-$desired_release" ne "$installed[1]-$installed[2]") {
	    DEBUG("   --> version mismatch - registering for update...\n");
	    SYSLOG("Registering locally installed OS package $full_rpm_name for update");
	    push(@rpms_to_install,$filename);
	} else {
	    DEBUG("   --> $desired_rpm[0] is already installed\n");
	}
    }

    # Do the transactions with gool ol' rpm command line (cuz perl interface sucks).

    my $count = @rpms_to_install;
    $losf_os_packages_updated += $count; 

    if( @rpms_to_install eq 0 ) {
	print_info_in_green("OK");
	INFO(": OS packages in sync ($num_rpms rpms checked)\n");
	return;
    } else {
	print_error_in_red("UPDATING");
	ERROR(": A total of $count OS distro rpm(s) need updating\n");
    }

    $losf_os_packages += @rpms_to_install;

    # This is for OS packages, for which there can be only 1 version
    # installed; hence we always upgrade

    my $rpm_root = "";

    # Add support for chroot install 

    if($LosF_provision::losf_provisioner eq "Warewulf" && $node_type ne "master" ) {
	my $chroot = query_warewulf_chroot($node_cluster,$node_type);
	if ( ! -d $chroot) {
	    MYERROR("Specified chroot directory is not available ($chroot)\n");
	} else {
	    INFO(" --> Using Warewulf chroot dir = $chroot\n");
	    $rpm_chroot = "--root $chroot";
	}
    }

    my $cmd = "rpm -Uvh $rpm_chroot "."@rpms_to_install";
    
    system($cmd);

    my $ret = $?;

    if ( $ret != 0 ) {
	MYERROR("Unable to install OS package RPMs (status = $ret)\n");
    }

    end_routine();
}

sub verify_rpms_removed {
    begin_routine();

    my @rpm_list        = @_;
    my @rpms_to_remove = ();
    my $num_rpms        = @rpm_list;

    if($num_rpms < 1) { return; }

    DEBUG("   --> Verifying desired OS RPMs are *not* installed ($num_rpms total)...\n");
    foreach $rpm (@rpm_list) {
	DEBUG("   --> Checking $rpm\n");

	# Installing from path provided by user on command-line?

	my $filename = "";
	my $arch     = rpm_arch_from_filename($rpm);

	# return array format = (name,version,release,arch)

	my @installed_rpm = is_rpm_installed($rpm);

	if( @installed_rpm ne 0 ) {
	    INFO("   --> $installed_rpm[0] is installed....removing\n");
	    SYSLOG("Registering locally installed $installed_rpm[0] for removal");
	    push(@rpms_to_remove,$rpm);
	}

    }

    # Do the transactions with gool ol' rpm command line (cuz perl interface sucks).

    my $count = @rpms_to_remove;

    if( $count eq 0 ) {
	return;
    } else {
	print "   --> ";
	print color 'red';
	print "UPDATING";
	print color 'reset';
	print ": A total of $count OS rpm(s) need to be removed $appliance\n";
    }

    # Remove unwanted os packages called out by user

    my $cmd = "rpm -ev "."@rpms_to_remove";
    
    system($cmd);

    my $ret = $?;

    if ( $ret != 0 ) {
	SYSLOG("** Local RPM removal unsuccessful (ret=$ret)");
	MYERROR("Unable to remove desired OS package RPMs (status = $ret)\n");
    } else {
	SYSLOG("RPM uninstall(s) successful");
    }

    end_routine();
}

# --------------------------------------------------------
# verify_custom_rpms (rpms)
# 
# Checks to see if input list of Custom rpms versions are
# installed; if not, installs desires packages with 
# user specified options.
# --------------------------------------------------------

sub verify_custom_rpms {
    begin_routine();

    my $appliance_ref = shift;
    my $rpm_ref       = shift;
    my $alias_ref     = shift;

    my $appliance = $$appliance_ref;
    my @rpm_list  = @$rpm_ref;
    my %aliases   = %$alias_ref;

    my %rpms_to_install = ();
    my $num_rpms        = @rpm_list;

    if($num_rpms < 1) { return; }

    DEBUG("   --> Verifying desired Custom RPMs are installed ($num_rpms total)...\n");

    # Resolve any group aliases: we pop to the end of the array, so
    # that multiple levels of alias resolution can be resolved (ie. an
    # alias might include another alias)

    foreach $rpm (@rpm_list) {
	if( $rpm =~ m/^@(\S+)/ ) {
	    my $group = $1;
	    DEBUG("   --> rpm group requested -> $group\n");
	    
	    if( ! exists $aliases{$group} ) {
		MYERROR("   --> Alias $group requested but not defined\n");
	    }
	    
	    # replace  @group with defined rpms
	    
	    foreach $rpm_group (@{$aliases{$group}}) {
		TRACE("   --> $group expansion - adding $rpm_group for $appliance\n");
		push(@rpm_list,$rpm_group);
	    }
	}
    }
    
    # reset num_rpms to account for alias expansion

    $num_rpms = @rpm_list;    

    foreach $rpm (@rpm_list) {

	my @rpm_array  = split(/\s+/,$rpm);
	my $rpm        = $rpm_array[0];

	if( $rpm =~ m/^@(\S+)/ ) { next; } # @groups names have already been expanded, skip this @group

	$losf_custom_packages_total++;

	# init any non-rpm command-line options 

	$losf_nomd5file = 0;

	# Determine desired rpm versionioning from options in config file; 

	my $desired_name    = "";
	my $desired_version = "";
	my $desired_release = "";
	my $desired_arch    = "";

	DEBUG("       --> Checking for version info for $rpm\n");

	if( $rpm_array[1] =~ m/name=(\S+)/ ) { 
	    $desired_name = $1;
	    DEBUG("            --> found version = $1\n");
	} 

	if( $rpm_array[2] =~ m/version=(\S+)/ ) { 
	    $desired_version = $1;
	    DEBUG("            --> found version = $1\n");
	} 

	if ( $rpm_array[3]  =~ m/release=(\S+)/ ) { 
	    $desired_release = $1;
	    DEBUG("            --> found release = $1\n");
	} 

	if ( $rpm_array[4] =~ m/arch=(\S+)/ ) { 
	    $desired_arch = $1;
	    DEBUG("            --> found arch = $1\n");
	}

	# Feb 2013: New config requirement with version 0.41 

	if( $desired_name eq "" || $desired_version eq "" || $desired_release eq "" || $desired_arch eq "" ) {
	    ERROR("\n");
	    ERROR("[ERROR]: Configuration error detected:\n");
	    ERROR("[ERROR]: --> $rpm\n");
	    ERROR("\n");
	    ERROR("[ERROR]: As of LosF v. 0.41, Custom RPM package definitions must include specific version, release and\n");
	    ERROR("[ERROR]: arch options for each desired package. \"losf addpkg\" will automatically include these\n");
	    ERROR("[ERROR]: options for new additions, but config files from earlier versions need to be upgraded.\n");
	    ERROR("[ERROR]: for compatability\n");
	    ERROR("\n");
	    ERROR("[ERROR]: Consider running \"losf config-upgrade\" to update your local copy to the latest\n");
	    ERROR("[ERROR]: configuration format.\n");
	    exit (1);
	} 

	my $full_rpm_name = "$rpm";

	# Cull rpm install options for this package

	my $md5_desired    = $rpm_array[5];  # <- required option for all custom packages (all others are optional)
	my $num_options    = @rpm_array;

	my $rpm_options    = "";
	my $install_method = "--upgrade ";   # we default to upgrade, may be overridden by parsing options below

	for(my $count = 6; $count < $num_options; $count++) {
	    $rpm_options = $rpm_options . validate_rpm_option($rpm_array[$count]);
	    if ( $rpm_array[$count] eq "INSTALL" ) {
		$install_method = ""; # nullify since user overrode default
	    }
	}

	$rpm_options = $install_method . $rpm_options;
	
	# We always use --nosignature as well since we frequently
	# don't import keys to computes; include --hash for visual feedback

	$rpm_options = $rpm_options . "--nosignature --hash -v";

	DEBUG("   --> rpm_options = $rpm_options\n");
	DEBUG("   --> Checking $rpm_array[0]\n");

	# Installing from path provided by user on command-line?

	my $filename = "";

	if ( "$MODE" eq "PXE" ) {
	    $filename = "$SRC_DIR/$desired_arch/$full_rpm_name.rpm";
	} else {
	    $filename = "$rpm_topdir/$desired_arch/$full_rpm_name.rpm";
	}

	# Pull down RPM if not cached locally

	if ( ! -s "$filename") {
	    my $cmd="yumdownloader -q --destdir=$rpm_topdir/$desired_arch $full_rpm_name";
	    INFO("   --> Downloading custom rpm -> $full_rpm_name\n");
	    system($cmd);
	}

	if ( ! -s "$filename" ) {
	    MYERROR("Unable to locate local Custom rpm-> $filename\n");
	}

	# 10/5/12 - give preferential treatment to cache directory. If
	# the file is present in the cache, we try to use
	# it. Otherwise, we revert to the standard rpm_topdir.

	if( $rpm_cachedir ne "NONE" ) {
	    if ( -s "$rpm_cachedir/$arch/$rpm_array[0].rpm" ) {
		DEBUG("Using cached rpm in $rpm_cachedir/$arch/$rpm_array[0].rpm");
		$filename="$rpm_cachedir/$arch/$rpm_array[0].rpm";
	    }
	}

	my @installed_rpms = is_os_rpm_installed("$desired_name.$desired_arch");

	# Decide if we need to install. Note that we build up arrays
	# of rpms to install on a per-rpm-option-combination basis.
	# This is to allow for multiple rpms to be installed, but it
	# is conceivable that some of the rpms which need to be
	# installed have different options specified. This uses a perl
	# array of hashes, so the syntax is slightly gnarly.

	my $installed_versions = @installed_rpms;

	if( $installed_versions == 0 ) {
	    verify_expected_md5sum($filename,$md5_desired) unless ( $losf_nomd5file) ;
	    DEBUG("   --> $rpm is not installed - registering for add...\n");
	    SYSLOG("Registering previously uninstalled $rpm for update");
	    push(@{$rpms_to_install{$rpm_options}},$filename);
	} elsif( ($installed_versions == 1 ) ) {
	    my @installed = split(' ',$installed_rpms[0]);
	    if ( "$desired_version-$desired_release" ne "$installed[1]-$installed[2]" )  {
		verify_expected_md5sum($filename,$md5_desired);
		DEBUG("   --> version mismatch - registering for update...\n");
		SYSLOG("Registering locally installed $rpm for update");
		push(@{$rpms_to_install{$rpm_options}},$filename);
	    } else {
		DEBUG("   --> $rpm is already installed\n");
	    }
	} else {
	    # This RPM has multiple versions currently
	    # installed. Logic is to check to see if the desired
	    # version is installed, if not, we register new
	    # installation. 

	    DEBUG("   --> Multiple versions installed, we must proceed with care skywalker...\n");

	    my $desired_installed = 0;

	    for(my $count = 0; $count < $installed_versions; $count++) {

		my @installed = split(' ',$installed_rpms[$count]);

		my $installed_ver = $installed[1];
		my $installed_rel = $installed[2];

		if ( "$desired_version-$desired_release" eq "$installed_ver-$installed_rel" )  {
		    $desired_installed = 1;
		}
	    }

	    if ( ! $desired_installed ) {
		verify_expected_md5sum($filename,$md5_desired);
		INFO("       --> $desired_name desired version not installed - registering for update...\n");
		SYSLOG("Registering locally installed $rpm for new multi-version");
		push(@{$rpms_to_install{$rpm_options}},$filename);
	    } else {
		DEBUG("   --> desired multi-rpm version is installed\n");
	    }
	}
    }

    # Do we have rpms to install

    my $count = 0;
    foreach my $options (keys %rpms_to_install) {
	foreach(@{$rpms_to_install{$options}}) {
	    $count++;
	}
    }

    $losf_custom_packages_updated += $count;

    if( $count == 0 ) {
	print_info_in_green("OK");
	INFO(": Custom packages in sync for $appliance: $num_rpms rpm(s) checked\n");
	return;
    } else {
	print_error_in_red("UPDATING");
	ERROR(": A total of $count custom rpm(s) need updating for $appliance\n");
    }

    # Do the transactions with gool ol' rpm command line (cuz perl interface sucks).

    foreach my $options (keys %rpms_to_install) {

	my $local_count = @{$rpms_to_install{$options}};
	print "\n";
	INFO("   --> Using rpm_options = $options (number of rpms = $local_count)\n");
	SYSLOG("Issuing transactions for $local_count rpm(s) ($options)");

	my $cmd = "rpm $options "."@{$rpms_to_install{$options}}";
    
	system($cmd);

	my $ret = $?;

	if ( $ret != 0 ) {
	    SYSLOG("** Local RPM update unsuccessful");
	    MYERROR("Unable to install Custom RPMs (status = $ret)\n");

	} else {
	    SYSLOG("RPM install(s) successful");
	}
	print "\n";
    }

    end_routine();
}

sub verify_custom_rpms_removed {
    begin_routine();

    my $appliance_ref = shift;
    my $rpm_ref       = shift;
    my $alias_ref     = shift;

    my $appliance     = $$appliance_ref;
    my @rpm_list      = @$rpm_ref;
    my %aliases       = %$alias_ref;

    my @rpms_to_remove = ();
    my $num_rpms       = @rpm_list;

    if($num_rpms < 1) { return; }

    DEBUG("   --> Verifying desired Custom RPMs are *not* installed ($num_rpms total)...\n");

    # Resolve any group aliases, we pop to the end of the array, so
    # that multiple levels of alias resolution can be resolved (ie. an
    # alias might include another alias)

    foreach $rpm (@rpm_list) {

	if( $rpm =~ m/^@(\S+)/ ) {
	    my $group = $1;
	    DEBUG("   --> rpm group requested -> $group\n");

	    if( ! exists $aliases{$group} ) {
		MYERROR("   --> Alias $group requested but not defined\n");
	    }

	    # replace  @group with defined rpms

	    foreach $rpm_group (@{$aliases{$group}}) {
		TRACE("   --> $group expansion - adding $rpm_group for $appliance\n");
		push(@rpm_list,$rpm_group);
	    }
	}
    }

    # reset num_rpms to account for alias expansion

    $num_rpms = @rpm_list;    

    foreach $entry (@rpm_list) {

	my @rpm_array  = split(/\s+/,$entry);
	my $rpm = $rpm_array[0];

	DEBUG("   --> Checking $rpm\n");

	if( $rpm =~ m/^@(\S+)/ ) { next; } # @groups names have already been expanded, skip this @group

	# Determine desired rpm versionioning from options in config file; 

	my $desired_name    = "";
	my $desired_version = "";
	my $desired_release = "";
	my $desired_arch    = "";

	DEBUG("       --> Checking for version info for $rpm\n");

	if( $rpm_array[1] =~ m/name=(\S+)/ ) { 
	    $desired_name = $1;
	    DEBUG("            --> found version = $1\n");
	} 

	if( $rpm_array[2] =~ m/version=(\S+)/ ) { 
	    $desired_version = $1;
	    DEBUG("            --> found version = $1\n");
	} 

	if ( $rpm_array[3]  =~ m/release=(\S+)/ ) { 
	    $desired_release = $1;
	    DEBUG("            --> found release = $1\n");
	} 

	if ( $rpm_array[4] =~ m/arch=(\S+)/ ) { 
	    $desired_arch = $1;
	    DEBUG("            --> found arch = $1\n");
	}

	if( $desired_name eq "" || $desired_version eq "" || $desired_release eq "" || $desired_arch eq "" ) {
	    ERROR("\n");
	    ERROR("[ERROR]: Configuration error detected:\n");
	    ERROR("[ERROR]: --> $entry\n");
	    ERROR("\n");
	    ERROR("[ERROR]: Consider running \"losf config-upgrade\" to update your local copy to the latest\n");
	    ERROR("[ERROR]: configuration format.\n");
	    exit (1);
	}

	# return array format = (name,version,release,arch)

	my @installed_rpms     = is_os_rpm_installed("$desired_name.$desired_arch");
	my $installed_versions = @installed_rpms;

	for(my $count = 0; $count < $installed_versions; $count++) {
	    my @installed = split(' ',$installed_rpms[$count]);

	    if( "$installed[1]-$installed[2]" eq "$desired_version-$desired_release" ) {
		$losf_custom_packages_updated++;
		print "   --> $installed[0]-$installed[1]-$installed[2] is installed....registering for removal\n";
		SYSLOG("Registering locally installed $installed_rpm[0]-$installed[1]-$installed[2] for removal");

		push(@rpms_to_remove,"$installed[0]-$installed[1]-$installed[2].$installed[3]");
	    }
	}

    }

    # Do the transactions with gool ol' rpm command line (since perl interface is below subpar).

    my $count = @rpms_to_remove;

    if( $count eq 0 ) {
	print_info_in_green("OK");
	INFO(": Verified desired Custom RPMs are *not* installed ($num_rpms total)...\n");
	return;
    } else {
	print_error_in_red("FAIL");
	print ": A total of $count Custom rpm(s) need to be removed for $appliance\n";
    }

    # Remove unwanted packages called out by user.

    my $cmd = "rpm -ev --nodeps "."@rpms_to_remove";
    
    system($cmd);

    my $ret = $?;

    if ( $ret != 0 ) {
	SYSLOG("** Local RPM removal unsuccessful (ret=$ret)");
	MYERROR("Unable to remove desired OS package RPMs (status = $ret)\n");
    } else {
	SYSLOG("RPM uninstall(s) successful");
    }

    end_routine();
}

# --------------------------------------------------------
# query_all_installed_rpms
# 
# Caches all currently installed rpms along with version
# and release number information.  We do this once and 
# cache for speed so that other utilities can query 
# against it (added 2/25/13)
# --------------------------------------------------------

sub query_all_installed_rpms {
    begin_routine();

    my @rpms_installed          = ();
    %losf_global_rpms_installed = ();

    DEBUG("   --> Caching all currently installed RPMs...\n");

     my $rpm_root = "";

    # Add support for chroot query
     if($LosF_provision::losf_provisioner eq "Warewulf" && $node_type ne "master" ) {
 	my $chroot = query_warewulf_chroot($node_cluster,$node_type);
 	if ( ! -d $chroot) {
 	    MYERROR("Specified chroot directory is not available ($chroot)\n");
 	} else {
	    $rpm_chroot = "--root $chroot";
	}
     }

    @rpms_installed = split('_LOSF_DELIM',`rpm -qa $rpm_chroot --queryformat '%{NAME} %{VERSION} %{RELEASE} %{ARCH}_LOSF_DELIM'`);

    # we now have all the rpms and their associated version,
    # release, and arch. cache the results in a global hash table for
    # later use (hash key is of the form "rpmname.arch")

    foreach $entry (@rpms_installed) {
	my @rpm_array  = split(/\s+/,$entry);
	my $key = "$rpm_array[0].$rpm_array[3]";

	# data structure is a hash -> array. Each array entry is a
	# string with 4 values separated by whitespace corresponding
	# to name, version, release, and arch respectively.  An array
	# is used here to allow for tracking of multiple versions of
	# the same rpm name being installed.

	push(@{$losf_global_rpms_installed{$key}},"@rpm_array");
    }

    $osf_cached_rpms = 1;
    end_routine();
}

sub is_os_rpm_installed {
    begin_routine();

    my $packagename   = shift;    # package keyname of the form "rpmname.arch"
    my @matching_rpms = ();

    # 2/23/13 - performance optimization: we now query against a cached
    # version of all locally installed rpms. Verify that cache has been generated.
    
    if(! $osf_cached_rpms ) {
	query_all_installed_rpms()
    }

    if (exists $losf_global_rpms_installed{$packagename} ) {
	@matching_rpms = @{$losf_global_rpms_installed{$packagename}};
    } 

    return(@matching_rpms);

}

# --------------------------------------------------------
# is_rpm_installed (packagename)
# 
# Checks to see if packagename is installed and returns
# list of matching packages if it is.
# --------------------------------------------------------

sub is_rpm_installed {
    begin_routine();

    my $packagename   = shift;

    my $chroot="";
    if(@_ >= 1) {
	$chroot = shift;
    }
	
    my @matching_rpms = ();
    my @empty_list    = ();

    DEBUG("   --> Checking if $packagename RPM is installed locally\n");

    if($chroot ne "") {
	$rpm_chroot = "--root $chroot";
    }

    @matching_rpms  = 
	split(' ',`rpm -q $rpm_chroot --queryformat '%{NAME} %{VERSION} %{RELEASE} %{ARCH}\n' $packagename`);

    if( $? != 0) {
	@matching_rpms = @empty_list;
    }

    end_routine();

    return(@matching_rpms);
}

# --------------------------------------------------------
# rpm_version_from_file()
# 
# Queries RPM versionioning info from existing RPM
# 
# Return: (name,version,release,arch)
# --------------------------------------------------------

sub rpm_version_from_file {
    begin_routine();

    my $filename = shift;
    my @rpm_info = ();

    DEBUG("   --> Querying RPM file $filename\n");

    if ( ! -e $filename ) { MYERROR("Unable to query rpm file $filename") };

    @rpm_info = split(' ',`rpm --nosignature -qp --queryformat '%{NAME} %{VERSION} %{RELEASE} %{ARCH}\n' $filename`);
    
    end_routine();
    return(@rpm_info);
}

# --------------------------------------------------------
# rpm_package_string_from_header()
# 
# --------------------------------------------------------

sub rpm_package_string_from_header {
    begin_routine();

    my @version = @_;

    end_routine();
    return("$version[0]-$version[1]-$version[2].$version[3]");
}

sub rpm_arch_from_filename {
    begin_routine();

    my $rpm = shift;
    my $config_arch;

    # Trim suffix of .rpm 

    if( $rpm =~ /^\S+.x86_64$/ ) {
	$config_arch = "x86_64"; 
    } elsif( $rpm =~ /^\S+.i386$/ ) {
	$config_arch = "i386"; 
    } elsif( $rpm =~ /^\S+.i686$/ ) {
	$config_arch = "i686"; 
    } elsif( $rpm =~ /^\S+.486$/ ) {
	$config_arch = "i486"; 
    } elsif( $rpm =~ /^\S+.586$/ ) {
	$config_arch = "i586"; 
    } elsif( $rpm =~ /^\S+.noarch$/ ) {
	$config_arch = "noarch"; 
    } else {
	MYERROR("Unknown RPM architecture -> $rpm\n");
    }

    end_routine();
    return($config_arch);
}

sub verify_expected_md5sum {
    begin_routine();

    my $file = shift;		# rpm file
    my $md5  = shift; 		# expected md5sum from input file

    my $local_md5 = md5sum_file($file);

    if($md5 ne $local_md5) {
	ERROR  ("   --> RPM md5sums do not match for $file\n");
	ERROR  ("       --> desired    = $md5\n");
	ERROR  ("       --> local      = $local_md5\n\n");
	MYERROR("FAILED: Aborting install\n");
    }

    return;
    end_routine;
}

sub md5sum_file {
    begin_routine();

    my $file = shift;
    my $digest = "";

    eval{
	open(FILE, $file) || MYERROR("Unable to access file for md5 calculation: $file");
	my $ctx = Digest::MD5->new;
	$ctx->addfile(*FILE);
	$digest = $ctx->hexdigest;
	close(FILE);
    };

    if($@){
	print $@;
	return "";
    }

    end_routine();
    return $digest;

}

sub validate_rpm_option {
    begin_routine();
    my $option = shift;
    my $rpm_mapping = "";

    DEBUG("Validating rpm option = $option\n");

    if( $option eq "NODEPS" )  {
	end_routine;
	return("--nodeps ");
    } elsif ( $option eq "IGNORESIZE" ) {
	end_routine;
	return("--ignoresize ");
    } elsif ( $option eq "INSTALL" ) {
	end_routine;
	return("--install ");
    } elsif ( $option eq "FORCE" ) {
	end_routine;
	return("--force ");
    } elsif ( $option eq "MULTI" ) {
	end_routine;
	return("--oldpackage ");
    } elsif ( $option eq "NOMD5FILE" ) {
	$losf_nomd5file = 1;
	end_routine;
	return("");
    } elsif ( $option =~ m/RELOCATE:(\S+):(\S+)/ ) {
	end_routine;
	return("--relocate $1=$2 ");
    } else {
	end_routine;
	ERROR("   [WARN]: Ignoring unsupported RPM option type -> $option\n");
	return("");
    }
}

1;

