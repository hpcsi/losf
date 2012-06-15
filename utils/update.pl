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
# Top-level update utility: used to synchronize all packages and
# config files for local node type.
#
# $Id$
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

# Default logging is set to ERROR

#$ENV{OSF_ECHO_MODE}="ERROR";

#my $logr = get_logger();
#$logr->level($ERROR);

use node_types;
use utils;

require "$osf_utils_dir/sync_config_utils.pl";

my $logr = get_logger();
$logr->level($ERROR);

parse_and_sync_os_packages();
parse_and_sync_custom_packages();
parse_and_sync_const_files();
parse_and_sync_softlinks();
parse_and_sync_services();
parse_and_sync_permissions();

1;

