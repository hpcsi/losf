#!/usr/bin/perl
#-----------------------------------------------------------------------bl-
#--------------------------------------------------------------------------
# 
# LosF - a Linux operating system Framework for HPC clusters
#
# Copyright (C) 2007-2013 Karl W. Schulz
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
# Utility to read a cluster's top-level rpm build directory from
# global config file.
#
# $Id$
#-------------------------------------------------------------------

use strict;
use LosF_paths;
use LosF_node_types;

use lib "$osf_log4perl_dir";
use lib "$osf_ini4perl_dir";
use lib "$osf_utils_dir/";

require "$osf_utils_dir/utils.pl";
require "$osf_utils_dir/parse.pl";
require "$osf_utils_dir/header.pl";

#---------------
# Initialization
#---------------

my $logr = get_logger();

verify_sw_dependencies(); 
$logr->level($ERROR);

#---------------------
# Determine node type
#---------------------

(my $node_cluster, my $node_type) = determine_node_membership();

#---------------------------
# Determine Local RPM TopDir
#---------------------------

(our $osf_rpm_topdir) = query_cluster_rpm_dir($node_cluster,$node_type);

DEBUG("\nRPM_TOPDIR = $osf_rpm_topdir\n");

1;
