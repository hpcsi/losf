#!/usr/bin/perl
#
# $Id: node_types.sh 151 2009-10-20 02:44:48Z karl $
#
#-----------------------------------------------------------------------
# Configuration paths definitions.
#-----------------------------------------------------------------------

package OSF_paths;
use strict;
use base 'Exporter';

our @EXPORT            = qw($osf_top_dir 
		            $osf_utils_dir
		            $osf_log4perl_dir
		            $osf_ini4perl_dir
			    $osf_osupdates_dir);

# TODO: snarf top_dir from input file.
		       
our $osf_top_dir       = "/home/build/admin/hpc_stack";

# 
our $osf_utils_dir     = "$osf_top_dir/utils";
our $osf_log4perl_dir  = "$osf_utils_dir/dependencies/mschilli-log4perl-d124229/lib";
our $osf_ini4perl_dir  = "$osf_utils_dir/dependencies/Config-IniFiles-2.52/lib";
our $osf_osupdates_dir = "$osf_top_dir/os-updates";

unless(-d $osf_osupdates_dir){
    mkdir $osf_osupdates_dir or die("[ERROR]: Unable to create dir ($osf_osupdates_dir)\n");
}

1;
