#!/usr/bin/perl
#
# $Id$
#
#-----------------------------------------------------------------------
# Configuration paths definitions.
#-----------------------------------------------------------------------

package OSF_paths;
use strict;
use base 'Exporter';
use File::Basename;

our @EXPORT            = qw($osf_top_dir 
			    $osf_config_dir
		            $osf_utils_dir
		            $osf_log4perl_dir
		            $osf_ini4perl_dir
			    $osf_osupdates_dir);

# Determine full path to LsoF install
		       
our $osf_top_dir       = "";

my ($filename,$basename) = fileparse($0);

# Strip off utils/ dir if necessary

if ($basename =~ m/(.*)\/utils\/$/) {
    our $osf_top_dir = $1;
} else {
    our $osf_top_dir = $basename;
}

print "osf_top_dir = $osf_top_dir\n";

our $osf_config_dir    = "$osf_top_dir/config";
our $osf_utils_dir     = "$osf_top_dir/utils";

our $osf_log4perl_dir  = "$osf_utils_dir/dependencies/mschilli-log4perl-d124229/lib";
our $osf_ini4perl_dir  = "$osf_utils_dir/dependencies/Config-IniFiles-2.52/lib";
our $osf_osupdates_dir = "$osf_top_dir/os-updates";

unless(-d $osf_osupdates_dir){
    mkdir $osf_osupdates_dir or die("[ERROR]: Unable to create dir ($osf_osupdates_dir)\n");
}

1;
