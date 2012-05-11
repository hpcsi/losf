#!/usr/bin/perl
#-----------------------------------------------------------------------bl-
#--------------------------------------------------------------------------
# 
# LosF - a Linux operating system Framework for HPC clusters
#
# Copyright (C) 2007,2008,2009,2010,2011,2012 Karl W. Schulz
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
# Utility Functions
#
# $Id$
#--------------------------------------------------------------------------

use OSF_paths;

use lib "$osf_log4perl_dir";
use lib "$osf_rpm2_dir";
use lib "$osf_rpm2_arch_dir";

use rpm_topdir;
use Sys::Syslog;  
use RPM2;

# --------------------------------------------------------
# verify_rpms (rpms)
# 
# Checks to see if input list of rpms versions are
# installed; if not, installs desires packages.
# --------------------------------------------------------

sub verify_rpms {
    begin_routine();

    my @rpm_list        = @_;
    my @rpms_to_install = ();
    my $num_rpms        = @rpm_list;

    if($num_rpms < 1) { return; }

#    my $db = RPM2->open_rpm_db ();
    my $db = RPM2->open_rpm_db ();
    my $tr = RPM2->create_transaction(RPM2->vsf_nohdrchk);

    INFO("   --> Verifying desired OS RPMs are installed ($num_rpms total)...\n");
    foreach $rpm (@rpm_list) {
	DEBUG("   --> Checking $rpm\n");

	my $arch     = rpm_arch_from_filename($rpm);
	my $filename = "$rpm_topdir/$arch/$rpm.rpm";

	if ( ! -s "$filename" ) {
	    MYERROR("Unable to locate local OS rpm-> $filename\n");
	}

	my $desired_rpm = RPM2->open_package("$filename");
	my ($installed) = sort { $b <=> $a } $db->find_by_name($desired_rpm->name);

	if( ! $installed ) {
	    INFO("   --> ".$desired_rpm->name." is not installed - registering for add...\n");
#	    $tr->add_install($desired_rpm);

	    # ks (5/7/12): i'll be damned, the rpm2 interface can't do multiple packages and apparently it has been a 
	    # known issue since 2005.  
	    # 
	    # that's really sad.

	    push(@rpms_to_install,$filename);
	    
	} elsif ($desired_rpm != $installed ) {
	    INFO("   --> version mismatch\n");
	}

#	if(is_rpm_installed($_) == 0) {
#	    INFO("   --> $_ is not installed - registering for add\n");
#	    push(@rpms_to_install,$_);
#	} else {
#	    INFO("   --> $_ is already installed\n");
#	}
    }



#    $tr->order();
#    $tr->check();
#    $tr->run();

    $tr->close_db();

    # Do the transactions with gool ol' rpm command line.

    if(@rpms_to_install eq 0 ) {
	INFO("   --> OK: OS packages in sync\n");
	return;
    }

    my $cmd = "rpm -Uvh "."@rpms_to_install";

    system($cmd);

    my $ret = $?;

    if ( $ret != 0 ) {
	MYERROR("Unable to install OS package RPMs (status = $ret)\n");
    }

    end_routine();
}

sub verify_rpms2 {
    begin_routine();

    my @rpm_list        = @_;
    my @rpms_to_install = ();
    my $num_rpms        = @rpm_list;

    if($num_rpms < 1) { return; }

    INFO("   --> Verifying desired OS RPMs are installed ($num_rpms total)...\n");
    foreach $rpm (@rpm_list) {
	DEBUG("   --> Checking $rpm\n");

	my $arch     = rpm_arch_from_filename($rpm);
	my $filename = "$rpm_topdir/$arch/$rpm.rpm";

	if ( ! -s "$filename" ) {
	    MYERROR("Unable to locate local OS rpm-> $filename\n");
	}

	# return array format = (name,version,release,arch)

	my @desired_rpm   = rpm_version_from_file2($filename);
	my @installed_rpm = is_rpm_installed2($rpm,$arch);

#	print "desired:   $desired_rpm[1] - $desired_rpm[2]\n";
#	print "installed: $installed_rpm[1] - $installed_rpm[2]\n";
	
	if( @installed_rpm eq 0 ) {
	    INFO("   --> $desired_rpm[0] is not installed - registering for add...\n");
	} elsif( "$desired_rpm[1]-$desired_rpm[2]" != "$installed_rpm[1]-$installed_rpm[2]") {
	    INFO("   --> version mismatch\n");
	} else {
	    DEBUG("   --> $desired_rpm[0] is already installed\n");
	}

    }

    # Do the transactions with gool ol' rpm command line (cuz perl interface sucks).

    if( @rpms_to_install eq 0 ) {
	INFO("   --> OK: OS packages in sync ($num_rpms rpms checked)\n");
	return;
    }

    # This is for OS packages, for which there can be only 1 version
    # installed; hence we always upgrade

    my $cmd = "rpm -Uvh "."@rpms_to_install";

    system($cmd);

    my $ret = $?;

    if ( $ret != 0 ) {
	MYERROR("Unable to install OS package RPMs (status = $ret)\n");
    }

    end_routine();
}

# --------------------------------------------------------
# is_rpm_installed (packagename)
# 
# Checks to see if packagename is installed and returns
# list of matching packages if it is.
# --------------------------------------------------------

sub is_rpm_installed {
    begin_routine();

    my $packagename    = shift;
    my @matching_rpms = ();

    DEBUG("   --> Checking if $packagename RPM is installed locally\n");

    $db = RPM2->open_rpm_db(RPM2->vsf_nosha1header);

    @matching_rpms = $db->find_by_name($packagename);

    $db = undef;

    end_routine();
    return(@matching_rpms);
}

sub is_rpm_installed2 {
    begin_routine();

    my $packagename   = shift;
    my @matching_rpms = ();

    DEBUG("   --> Checking if $packagename RPM is installed locally\n");

    @matching_rpms  = 
	split(' ',`rpm -q --queryformat '%{NAME} %{VERSION} %{RELEASE} %{ARCH}\n' $packagename`);

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

    my $filename        = shift;
    my @rpm_header_info = ();

    DEBUG("   --> Querying RPM file $filename\n");

    if ( ! -e $filename ) { MYERROR("Unable to query rpm file $filename") };
    
    $pkg = RPM2->open_package($filename);
    
#    my $name    = $pkg->tagformat("%{NAME}");
#    my $version = $pkg->tagformat("%{VERSION}-%{RELEASE}");
#    my $arch    = $pkg->tagformat("%{ARCH}");

    push(@rpm_header_info,$pkg->tagformat("%{NAME}"));
    push(@rpm_header_info,$pkg->tagformat("%{VERSION}"));
    push(@rpm_header_info,$pkg->tagformat("%{RELEASE}"));
    push(@rpm_header_info,$pkg->tagformat("%{ARCH}"));

    $pkg = undef;

    end_routine();
    return(@rpm_header_info);
}

sub rpm_version_from_file2 {
    begin_routine();

    my $filename = shift;
    my @rpm_info = ();

    DEBUG("   --> Querying RPM file $filename\n");

    if ( ! -e $filename ) { MYERROR("Unable to query rpm file $filename") };

    @rpm_info = split(' ',`rpm -qp --queryformat '%{NAME} %{VERSION} %{RELEASE} %{ARCH}\n' $filename`);
    
#    print "name    = $rpm_info[0]\n";
#    print "version = $rpm_info[1]\n";
#    print "release = $rpm_info[2]\n";
#    print "arch    = $rpm_info[3]\n";

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
#    return("$version[0]-$version[1]-$version[2] (arch=$version[3])");
    return("$version[0]-$version[1]-$version[2].$version[3]");
}

sub rpm_arch_from_filename {
    begin_routine();

    my $rpm = shift;
    my $config_arch;

    if( $rpm =~ /^\S+.x86_64$/ ) {
	$config_arch = "x86_64"; 
    } elsif( $rpm =~ /^\S+.i386$/ ) {
	$config_arch = "i386"; 
    } elsif( $rpm =~ /^\S+.i686$/ ) {
	$config_arch = "i686"; 
    } elsif( $rpm =~ /^\S+.noarch$/ ) {
	$config_arch = "noarch"; 
    } else {
	MYERROR("Unknown RPM architecture -> $rpm\n");
    }

    end_routine();
    return($config_arch);
}

1;

