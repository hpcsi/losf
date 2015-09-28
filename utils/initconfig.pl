#!/usr/bin/env perl
#-----------------------------------------------------------------------bl-
#--------------------------------------------------------------------------
# 
# LosF - a Linux operating system Framework for HPC clusters
#
# Copyright (C) 2007-2015 Karl W. Schulz <losf@koomie.com>
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
# Initialize a skeleton configuration for new cluster.
#--------------------------------------------------------------------------

use warnings;
use strict;
use File::Basename;
use File::Path;
use File::Copy;
use Getopt::Long;
use LosF_utils;

my $newCluster   = "";
my $losf_top_dir = "";
my $changedFlag  = 0;
my $template_dir = "";
my $help         = 0;
my $version      = "";

sub usage {
    print "\ninitconfig: convenience utility used to create a basic starting\n";
    print "configuration template for a new LosF cluster designation.\n";
    print "\n";
    print "usage: initconfig [OPTIONS] <cluster-name> [template-dir]\n";
    print "\n";
    print "    -h          Show help message.\n";
    print "    -v          Print version number and exit.\n";
    exit(1);
}

#-------------------------------------------------
# Main front-end for initconfig command-line tool
#-------------------------------------------------

GetOptions("h"       => \$help,
     "version"       => \$version) || usage();

usage() if ($help);

if ($version) {
    print_version();
    exit(0);
}

verify_sw_dependencies();
my $logr = get_logger(); $logr->level($INFO);

# Only one LosF instance at a time
losf_get_lock();

$newCluster = shift || '';

if( $newCluster eq '') { 
    usage(); }

my ($filename,$basename) = fileparse($0);

# Strip off utils/ dir if necessary

if ($basename =~ m/(.*)\/utils\/$/) {
    $losf_top_dir = $1;
} else {
    $losf_top_dir = $basename;
}

my $nonDefaultTemplate = 0;

if( @ARGV >= 1 ) {
    $template_dir = shift;
    my $resolve_dir = 0;
    if ( -d $template_dir) {
	$resolve_dir = 1;
    } elsif ( -d "$losf_top_dir/config/$template_dir") {
	$template_dir = "$losf_top_dir/config/$template_dir";
	$resolve_dir = 1;
    }
    
    if( $resolve_dir == 0) {
	print "ERROR: Unable to access requested template directory -> $template_dir\n";
	exit 1;
    }
    $nonDefaultTemplate = 1;
}

# Use default template_dir if none provided 

if ($template_dir eq "") {
    $template_dir = "$losf_top_dir/config/skeleton_template";
}

# Determine config_dir

my $config_dir = $ENV{'LOSF_CONFIG_DIR'};

my $config_dir_specified = 0;

if ( defined $ENV{'LOSF_CONFIG_DIR'} ) {
    $config_dir_specified = 1;
} else {
    my $local_config_file="$losf_top_dir/config/config_dir";

    if ( -s $local_config_file ) {
	open (my $IN,"<$local_config_file") || die("[ERROR]: Unable to open file ($local_config_file)\n");
	my $local_config_dir = <$IN>;
	chomp($local_config_dir);
	close($IN);

	# remove trailing slash if present
	if($local_config_dir =~ /(.*)\/$/) {
	    chop($local_config_dir);
	}

	$config_dir = $local_config_dir;
	$config_dir_specified = 1;
    } 
}

if ( $config_dir_specified == 0) {
    ERROR("\nError: An LosF config directory was not provided. You must provide a desired config\n");
    ERROR("path for your local cluster. This can be accomplished via one of two methods:\n\n");
    ERROR("  (1) Add your desired config path to the file -> $losf_top_dir/config/config_dir\n");
    ERROR("  (2) Set the LOSF_CONFIG_DIR environment variable\n\n");
    exit 1;
}

# Establish hostname/domainname
    
INFO("\n");
INFO("Initializing basic configuration skeleton for new cluster -> $newCluster\n");
INFO("Using LosF config dir -> $config_dir\n");

my ($hostname,$domain_name) = query_local_network_name();

# Do the deed for non-existent config files

if ( ! -d $config_dir ) {
    INFO("--> creating path for $config_dir\n");
    mkpath("$config_dir") || MYERROR("Unable to create path $config_dir");
    $changedFlag = 1;
}

if ( ! -s "$config_dir/config.machines" ) {
    INFO("--> creating $config_dir/config.machines file\n");

    my $template = "$template_dir/config.machines";

    if ( ! -s $template ) {
	MYERROR("ERROR: Missing template file -> $template");
    }

    open(IN, "<$template")                    || die "Cannot open $template\n";
    open(OUT,">$config_dir/config.machines")  || die "Cannot create $config_dir/config.machines\n";

    while(my $line=<IN>) {
	if($line =~ /^clusters\s+=\s+FOO/) {
	    print OUT "clusters = $newCluster\n";
	} elsif($line =~ /^clusters\s+=\s+default/) {
	    print OUT "clusters = $newCluster\n";
	} elsif ($line =~ /^\[FOO\]/) {
	    print OUT "\[$newCluster\]\n";
	} elsif ($line =~ /^\[default\]/) {
	    print OUT "\[$newCluster\]\n";
	} elsif ($line =~ /^master\s+=\s+default/) {
	    print OUT "master = $hostname\n";
	} elsif ($line =~ /^domainname\s+=\s+yourdomain.org/) {
	    print OUT "domainname = $domain_name\n";
	} elsif ($line =~ /^rpm_dir\s+=\s+default/) {
	    # create a default rpm_dir
	    my $rpm_dir = "$config_dir/$newCluster/rpms";
	    if ( ! -d $rpm_dir) {
		INFO("--> creating path for default rpm_dir -> $rpm_dir\n");
		mkpath("$rpm_dir") || MYERROR("Unable to create path $rpm_dir");
	    }
	    print OUT "rpm_dir = $rpm_dir\n";
	} else {
	    print OUT $line;
	}
    }

    close(IN);
    close(OUT);
    $changedFlag = 1;
}

# Cluster-specific config file

if ( ! -e "$config_dir/config.$newCluster" ) {
    INFO("--> creating $config_dir/config.$newCluster file\n");

    my $template = "$template_dir/config.default";

    if ( ! -s $template ) {
	MYERROR("Missing template file -> $template");
    }
    
    copy("$template","$config_dir/config.$newCluster") || print "ERROR: Unable to update config.$newCluster\n";
    $changedFlag = 1;
}

# Cluster-specific IPs file

if ( ! -e "$config_dir/ips.$newCluster" ) {
    INFO("--> creating $config_dir/ips.$newCluster file\n");
    
    my $template = "$losf_top_dir/config/skeleton_template/ips.default";
    if ( ! -s $template ) {
	MYERROR("Missing template file -> $template");
    }
    
    copy("$template","$config_dir/ips.$newCluster") || print "ERROR: Unable to update ips.$newCluster\n";
    $changedFlag = 1;
}

# OS Packages config file

if ( ! -e "$config_dir/os-packages/$newCluster/packages.config" ) {
    print "--> creating $config_dir/os-packages/$newCluster/packages.config file\n";

    if ( ! -d "$config_dir/os-packages/$newCluster" ) {
	mkpath("$config_dir/os-packages/$newCluster") || die("[ERROR]: Unable to create path for os-packages");
    }

    my $template = "$template_dir/os-packages/default/packages.config";
    if ( ! -s $template ) {
	MYERROR("Missing template file -> $template\n");
    }

    copy("$template","$config_dir/os-packages/$newCluster/packages.config") || MYERROR("Unable to update packages.config\n");
    $changedFlag = 1;
}

# Custom Packages config file

if ( ! -e "$config_dir/custom-packages/$newCluster/packages.config" ) {
    INFO("--> creating $config_dir/custom-packages/$newCluster/packages.config file\n");

    if ( ! -d "$config_dir/custom-packages/$newCluster" ) {
	mkpath("$config_dir/custom-packages/$newCluster") || MYERROR("Unable to create path for custom-packages");
    }

    my $template = "$template_dir/custom-packages/default/packages.config";
    if ( ! -s $template ) {
	MYERROR("Missing template file -> $template");
    }

    copy("$template","$config_dir/custom-packages/$newCluster/packages.config") || MYERROR("Unable to update packages.config");
    $changedFlag = 1;
}

# const_files directory

if ( ! -d "$config_dir/const_files/$newCluster" ) {
    mkpath("$config_dir/const_files/$newCluster") || 
	MYERROR("Unable to create path for const_files/$newCluster");
    INFO("--> creating $config_dir/const_files/$newCluster directory\n");

	INFO("--> creating $config_dir/const_files/$newCluster/notify_header file\n");
        copy("$template_dir/notify_header","$config_dir/const_files/$newCluster") || MYERROR("Unable to copy notify_header");

    if ( ! -d "$config_dir/const_files/$newCluster/master" ) {
	mkpath("$config_dir/const_files/$newCluster/master") || 
	    MYERROR("Unable to create path for const_files/$newCluster/master");
	INFO("--> creating $config_dir/const_files/$newCluster/master directory\n");


    }
    $changedFlag = 1;
}



if ( $changedFlag == 0) {
    INFO("--> Basic config files for cluster \"$newCluster\" already present\n");
    INFO("\nNo additional initialization required.\n");
} else {
    INFO("\nBasic initialization complete.\n");
}

# Check for any provided const_files when using non-default template

if($nonDefaultTemplate) {

    INFO("\nChecking for const_files supplied with custom template ($template_dir)\n");

    my $indir = "$template_dir/const_files/default";
    opendir my $dirHandle, $indir or MYERROR("Unable to access $indir");

    my @dirs = grep {-d "$indir/$_" && ! /^\.{1,2}$/} readdir($dirHandle);
    
    foreach my $dir (@dirs) {
	INFO "--> detected const_files subdirectory for type = $dir\n";
	
	find( sub {
	    return if (-d $_);
	    
	    if (-e "$config_dir/const_files/$newCluster/$dir/$_") {
		INFO("    --> $_ const_file already present...not copying\n");
		return;
	    }
	    
	    INFO("    --> $_ file detected, copying file to new config\n");

	    if( ! -d "$config_dir/const_files/$newCluster/$dir") {
		mkpath("$config_dir/const_files/$newCluster/$dir") || 
		    MYERROR("Unable to create path for const_files/$newCluster/$dir");
	    }

	    copy("$_","$config_dir/const_files/$newCluster/$dir/") || MYERROR("Unable to copy file $_ ($dir)");
	    return;
	      },"$template_dir/const_files/default/$dir");
    }

#    INFO("\nChecking for missing OS dependencies and caching RPMs locally\n");
    
#    my $pkg_manager = check_for_package_manager("updatepkg");
#    init_local_os_config_file_parsing("$losf_custom_config_dir/os-packages/$newCluster/packages.config");
#    my @os_rpms = query_cluster_config_os_packages($newCluster,$main::node_type);
#    verify_rpms(@os_rpms);
#    INFO("--> package manger = $pkg_manager\n");
#    parse_and_sync_os_packages();
}

# Done with lock

losf_get_lock();

1;
