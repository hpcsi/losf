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
# Configuration paths definitions.
#--------------------------------------------------------------------------

package LosF_paths;
use strict;
use base 'Exporter';
use File::Basename;

our @EXPORT            = qw($losf_top_dir 
			    $losf_config_dir
                            $losf_custom_config_dir
		            $losf_utils_dir
		            $losf_log4perl_dir
		            $losf_ini4perl_dir);

# Determine full path to LosF install
		       
our $losf_top_dir = "";

my ($filename,$basename) = fileparse($0);

# Strip off utils/ dir if necessary

if ($basename =~ m/(.*)\/utils\/$/) {
    our $losf_top_dir = $1;
} else {
    our $losf_top_dir = $basename;
}

sub print_no_defined_config_path_message {

    print "\nError: A valid LosF config directory was not detected. You must provide a valid config\n";
    print "path for your local cluster. This can be accomplished via one of two methods:\n\n";
    print "  (1) Add your desired config path to the file -> $losf_top_dir/config/config_dir\n";
    print "  (2) Set the LOSF_CONFIG_DIR environment variable\n\n";
    print "Example configuration files are availabe at -> $losf_top_dir/config/config_example\n";

    print_initconfig_suggestion();

    exit(1);
}

sub print_initconfig_suggestion {
    print "\nNote: for new systems, you can also run \"initconfig <YourClusterName>\" to create\n";
    print "a starting LosF configuration template.\n\n";
}

# ----------------------------------------------------------------------
# v0.43.0 Change:
#
# require user to provide us with a config path (we no longer assume
# it is local to LosF install since users will likely want to use
# their own SCM for config files). Config path can be specified in one
# of two ways:
# 
# 1. LOSF_CONFIG_DIR environment variable
# 2. config/config_dir file in locally running LosF path
#
# The environment variable takes precedence over config_dir setting
# ----------------------------------------------------------------------

# Check for priviliged credentials

if ($ENV{'USER'} ne "root" ) {
    print "[ERROR]: LosF requires elevated credentials for execution.\n";
    exit 1;
}

# Allow for potential separation of LosF install path and LosF
# configuration path. By default, we assume a config/ dir local to the
# LosF install but this can be overridden by an environment variable.

my $config_dir = $ENV{'LOSF_CONFIG_DIR'};

if ( defined $ENV{'LOSF_CONFIG_DIR'} ) {
    if ( -d $config_dir ) {
	# remove trailing slash if present

	if($config_dir =~ /(.*)\/$/) {
	    chop($config_dir);
	}
	our $losf_config_dir        = $config_dir;
	our $losf_custom_config_dir = $config_dir;
    } else {
	print "\n";
	print "[ERROR]: LOSF_CONFIG_DIR provided path does not exist or is not a directory.\n\n";
	print "Using LosF config dir -> $config_dir\n";
	print_initconfig_suggestion();
	exit 1;
    }
} else {
    my $local_config_file="$losf_top_dir/config/config_dir";
    if ( -s $local_config_file ) {
	open (my $IN,"<$local_config_file") || MYERROR("Unable to open  file ($local_config_file)");
	my $local_config_dir = <$IN>;
	chomp($local_config_dir);
	close($IN);

	if ( -d $local_config_dir ) {

	    # remove trailing slash if present
	    if($local_config_dir =~ /(.*)\/$/) {
		chop($local_config_dir);
	    }

	    our $losf_config_dir        = "$local_config_dir";
	    our $losf_custom_config_dir = "$local_config_dir";
	} else {
	    print_no_defined_config_path_message();
	} 
    } else {
	print_no_defined_config_path_message();
    }
}

our $losf_utils_dir         = "$losf_top_dir/utils";
our $losf_log4perl_dir      = "$losf_utils_dir/dependencies/mschilli-log4perl-d124229/lib";
our $losf_ini4perl_dir      = "$losf_utils_dir/dependencies/Config-IniFiles-2.68/lib";

1;
