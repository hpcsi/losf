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
# Initialize a skeleton configuration for new cluster.
#--------------------------------------------------------------------------

use warnings;
use strict;
use File::Basename;
use File::Path;
use File::Copy;

my $newCluster   = "";
my $losf_top_dir = "";
my $changedFlag  = 0;

$newCluster = shift || '';

if( $newCluster eq '') {
    print "\ninitconfig: convenience utility used to create a basic starting\n";
    print "configuration template for a new LosF cluster designation.\n";
    print "\n";
    print "usage: initconfig <cluster-name>\n";
    print "\n";

    exit 1;
}

my ($filename,$basename) = fileparse($0);

# Strip off utils/ dir if necessary

if ($basename =~ m/(.*)\/utils\/$/) {
    $losf_top_dir = $1;
} else {
    $losf_top_dir = $basename;
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
    print "\nError: An LosF config directory was not provided. You must provide a desired config\n";
    print "path for your local cluster. This can be accomplished via one of two methods:\n\n";
    print "  (1) Add your desired config path to the file -> $losf_top_dir/config/config_dir\n";
    print "  (2) Set the LOSF_CONFIG_DIR environment variable\n\n";
    exit 1;
}

# Do the deed for non-existent config files
    
print "\n";
print "Initializing basic configuration skeleton for new cluster -> $newCluster\n";

if ( ! -d $config_dir ) {
    print "--> creating path for $config_dir\n";
    mkpath("$config_dir") || die("[ERROR]: Unable to create path $config_dir");
    $changedFlag = 1;
}

if ( ! -s "$config_dir/config.machines" ) {
    print "--> creating $config_dir/config.machines file\n";

    my $template = "$losf_top_dir/config/skeleton_template/config.machines";
    if ( ! -s $template ) {
	print "ERROR: Missing template file -> $template\n";
	exit 1;
    }

    open(IN, "<$template")                    || die "Cannot open $template\n";
    open(OUT,">$config_dir/config.machines")  || die "Cannot create $config_dir/config.machines\n";

    my $hostname    = `hostname -s`; chomp($hostname);
    my $domain_name = `dnsdomainname 2> /dev/null`; chomp($domain_name);

    while(my $line=<IN>) {
	if($line =~ /^clusters\s+=\s+FOO/) {
	    print OUT "clusters = $newCluster\n";
	} elsif ($line =~ /^\[FOO\]/) {
	    print OUT "\[$newCluster\]\n";
	} elsif ($line =~ /^default\s+=\s+default/) {
	    print OUT "default = $hostname\n";
	} elsif ($line =~ /^domainname\s+=\s+yourdomain.org/) {
	    print OUT "domainname = $domain_name\n";
	} elsif ($line =~ /^rpm_dir\s+=\s+default/) {
	    # create a default rpm_dir
	    my $rpm_dir = "$config_dir/$newCluster/rpms";
	    if ( ! -d $rpm_dir) {
		print "--> creating path for default rpm_dir -> $rpm_dir\n";
		mkpath("$rpm_dir") || die("[ERROR]: Unable to create path $rpm_dir");
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
    print "--> creating $config_dir/config.$newCluster file\n";
    
    my $template = "$losf_top_dir/config/skeleton_template/config.default";
    if ( ! -s $template ) {
	print "ERROR: Missing template file -> $template\n";
	exit 1;
    }
    
    copy("$template","$config_dir/config.$newCluster") || print "ERROR: Unable to update config.$newCluster\n";
    $changedFlag = 1;
}

# Cluster-specific IPs file

if ( ! -e "$config_dir/ips.$newCluster" ) {
    print "--> creating $config_dir/ips.$newCluster file\n";
    
    my $template = "$losf_top_dir/config/skeleton_template/ips.default";
    if ( ! -s $template ) {
	print "ERROR: Missing template file -> $template\n";
	exit 1;
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

    my $template = "$losf_top_dir/config/skeleton_template/os-packages/packages.config";
    if ( ! -s $template ) {
	print "ERROR: Missing template file -> $template\n";
	exit 1;
    }

    copy("$template","$config_dir/os-packages/$newCluster/packages.config") || 
	print "ERROR: Unable to update packages.config\n";
    $changedFlag = 1;
}

# Custom Packages config file

if ( ! -e "$config_dir/custom-packages/$newCluster/packages.config" ) {
    print "--> creating $config_dir/custom-packages/$newCluster/packages.config file\n";

    if ( ! -d "$config_dir/custom-packages/$newCluster" ) {
	mkpath("$config_dir/custom-packages/$newCluster") || die("[ERROR]: Unable to create path for custom-packages");
    }

    my $template = "$losf_top_dir/config/skeleton_template/custom-packages/packages.config";
    if ( ! -s $template ) {
	print "ERROR: Missing template file -> $template\n";
	exit 1;
    }

    copy("$template","$config_dir/custom-packages/$newCluster/packages.config") || 
	print "ERROR: Unable to update packages.config\n";
    $changedFlag = 1;
}

if ( $changedFlag == 0) {
    print "--> Basic config files for cluster $newCluster already present\n";
    print "\nNo additional initialization required.\n";
} else {
    print "\nBasic initialization complete.\n";
}

1;
