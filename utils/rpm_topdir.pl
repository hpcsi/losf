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
# Utility to read a cluster's top-level rpm build directory from
# global config file.
#--------------------------------------------------------------------------

use strict;
use LosF_paths;
use LosF_node_types;

use lib "$losf_utils_dir/";

require "$losf_utils_dir/utils.pl";
require "$losf_utils_dir/parse.pl";
require "$losf_utils_dir/header.pl";

#---------------
# Initialization
#---------------

my $logr = get_logger();

verify_sw_dependencies(); 
$logr->level($ERROR);

my $standalone = $ENV{'LOSF_STANDALONE_UTIL'};

#---------------------
# Determine node type
#---------------------

(my $node_cluster, my $node_type) = determine_node_membership();

#---------------------------
# Determine Local RPM TopDir
#---------------------------

(our $osf_rpm_topdir) = query_cluster_rpm_dir($node_cluster,$node_type);

if($standalone == 1) {
    print "[LosF] RPM topdir:      $osf_rpm_topdir\n";
}

DEBUG("\nRPM_TOPDIR = $osf_rpm_topdir\n");

1;

