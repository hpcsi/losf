#!/usr/bin/env perl
#
#-----------------------------------------------------------------------bl-
#--------------------------------------------------------------------------
# 
# LosF - a Linux operating system Framework for HPC clusters
#
# Copyright (C) 2007-2019 Karl W. Schulz <losf@koomie.com>
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
# Versioning header
#--------------------------------------------------------------------------

sub print_header {

    my $width = 24;
    my $logr  = get_logger();
    my $ver   = "";

    if ( ! -e "$losf_top_dir/VERSION" ) {
	MYERROR("Unable to obtain version...please verify local LosF install");
    } else {
	open ($IN,"<$losf_top_dir/VERSION") || MYERROR("Unable to open VERSION file");
	$ver = <$IN>;
	chomp($ver);
	close($IN);
    }

    INFO("\n");
    INFO("-"x $width . "\n");
    INFO("LosF: Version $ver\n");
    INFO("-"x $width . "\n");
    INFO("\n");
}

1;
