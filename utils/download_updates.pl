#!/usr/bin/perl
#
# $Id$
#
#-----------------------------------------------------------------------
# Utility for downloading updated OS rpms from a centralized
# mirror/repository.
# 
# Originally: 4-15-2007 - ks
#
# Questions/Problems?: karl@tacc.utexas.edu
# Texas Advanced Computing Center
#-----------------------------------------------------------------------

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

verify_sw_dependencies();
print_header();
INFO("--> Mode = Download OS Updates   \n");
INFO("-"x 50 ."\n");

#---------------------
# Determine node type
#---------------------

(my $node_cluster, my $node_type) = determine_node_membership();

#---------------------------------
# Determine save location for rpms
#---------------------------------

chomp(my $DATE  = `date +%F`);
chomp(my $LDATE =`date +%F-%R`);
my $RPMDIR="$osf_osupdates_dir/$node_cluster/$node_type/$DATE";

unless(-d "$RPMDIR" ) {
    DEBUG("Creating $RPMDIR\n");
    `mkdir -p $RPMDIR`;
}

INFO("--> Saving downloaded rpms in $RPMDIR\n");

#-------------------------------------------
# Save the list of currently installed rpms
#-------------------------------------------

`rpm -qa >& $RPMDIR/rpms-previously-installed.$LDATE`;

my $UPDATE_MODE = "yum";

if ( $UPDATE_MODE eq "yum" ) {
    INFO("--> Prepping to download packages via yum\n");

    my $YUM_CONF    = "/etc/yum.conf";
    my $IGNORE_PKGS = "kernel* libibcm* libibcommon* libibverbs* libipathverbs* libmthca* libopensm* libosmcomp* libosmvendor* librdmacm* mstflint* opensm* libibumad* openib* ibutils* libsdp* iscsi-initiator-utils infiniband-diags* libcxgb3 bash* tcsh* fipscheck-check* fipscheck* libibmad* tvflash* libmlx4* perftest*"  ;

    #---------------------------------
    # Set correct packages to ignore 
    # for local host.
    #---------------------------------

    my $cmd ="/usr/bin/perl -p -i -e \"s|exclude=.+\$|exclude=$IGNORE_PKGS|\" $YUM_CONF";
    `$cmd`;

    #------------------
    # Download the rpms
    #------------------

    `yum -v update --downloadonly --downloaddir=$RPMDIR`;

} else {
    MYERROR("Package update mode is not supported ($UPDATE_MODE)\n");
}



#----------------------------------------------------
# Generate a quick list of the rpms so that
# the quick_check script can verify that the desired
# packages are installed.
#----------------------------------------------------

opendir(DIR,"$RPMDIR");
my @pkgs = grep(/\.rpm$/,readdir(DIR));
closedir(DIR);
my $num_pkgs = @pkgs;

if( $num_pkgs <= 0 ) {
    INFO("--> No new OS updates available at this time\n");
} else {
    INFO("--> Number of packages downloaded = $num_pkgs\n");
    `cd $RPMDIR; ls *.rpm >& rpm_list`;
}

