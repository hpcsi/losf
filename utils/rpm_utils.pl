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

use Sys::Syslog;  
use RPM2;

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

    $db = RPM2->open_rpm_db();

    @matching_rpms = $db->find_by_name($packagename);

    $db = undef;

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

1;

