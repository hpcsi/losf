#!/usr/bin/env perl
#-----------------------------------------------------------------------bl-
#--------------------------------------------------------------------------
# 
# LosF - a Linux operating system Framework for HPC clusters
#
# Copyright (C) 2007-2017 Karl W. Schulz <losf@koomie.com>
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
# Query [optional] underlying provisioning system in use.
#--------------------------------------------------------------------------

package LosF_provision;
use strict;
use LosF_paths;
use LosF_utils;

use lib "$losf_utils_dir";

require "$losf_utils_dir/parse.pl";
use Exporter qw(import);

our $losf_provisioner; # = main::query_provisioning_system();
our @EXPORT = qw($losf_provisioner);

sub init_provisioning_system {
    $losf_provisioner = main::query_provisioning_system();
}

1;
