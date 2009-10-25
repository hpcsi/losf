#!/usr/bin/perl
#
# $Id: node_types.sh 151 2009-10-20 02:44:48Z karl $
#
#-----------------------------------------------------------------------
# Utility for installing previously downloading OS updates
# from a centralized mirror/repository.
# 
# Originally: 4-15-2007 - ks
#
# Questions/Problems?: karl@tacc.utexas.edu
# Texas Advanced Computing Center
#-----------------------------------------------------------------------

use strict;
use OSF_paths;
use node_types;

use lib "$osf_log4perl_dir";
use lib "$osf_ini4perl_dir";
use lib "$osf_utils_dir/";

require "$osf_utils_dir/utils.pl";
require "$osf_utils_dir/parse.pl";
require "$osf_utils_dir/header.pl";

my $DEBUG_MODE=1;

#---------------
# Initialization
#---------------

verify_sw_dependencies();

print_header();
INFO("--> Mode = Install OS Updates   \n");
INFO("-"x 50 ."\n");

# Inputs -------------------

#export SRC_DIR=/share/home/0000/build/admin/os-updates/
#export INSTALL_DIR=/share/home/0000/build/admin/hpc_stack/
#export NODE_QUERY=/share/home/0000/build/admin/hpc_stack/node_types.sh
#export DEBUG=1

# End Inputs -------------------

#---------------------
# Determine node type
#---------------------

(my $node_cluster, my $node_type) = determine_node_membership();

#---------------------------------
# Determine read location for rpms
#---------------------------------

my $prod_date = query_global_config_os_sync_date($node_cluster,$node_type);
my $RPMDIR="$osf_osupdates_dir/$node_cluster/$node_type/$prod_date";

DEBUG("--> RPMDIR=$RPMDIR\n");
INFO ("--> Desired production date = $prod_date\n");

if ( ! -d $RPMDIR ) {
    MYERROR("Unable to find rpm directory for the desired production date!",
	    "Please be sure to run download_updates first and update your",
	    "global configuration file accordingly with the desired production",
	    "settings.");
}

INFO("--> Installing downloaded os-update rpms from:\n");
INFO("    $RPMDIR\n");

#-------------------
# Already installed?
#-------------------

INFO("--> Checking if desired rpms are already installed...\n");

my $NOT_UPDATED = 0;
my $MISSING_RPMS="";

opendir(DIR,"$RPMDIR");
my @pkgs = grep(/\.rpm$/,readdir(DIR));
closedir(DIR);

foreach my $loc_rpm  (@pkgs) {
    INFO("    --> rpm =  $loc_rpm\n");
}

# for i in $RPMDIR/*.rpm; do
#     export RESULT=`rpm -U --test $i 2>&1 | grep "already installed"`

#     if [ "x$RESULT" == "x" ];then

# 	if [ $DEBUG == 0 ];then 
# 	    echo "   --> desired rpm not installed $RESULT $i"
# 	fi
# 	MISSING_RPMS="$MISSING_RPMS $i"
# 	NOT_UPDATED=1
# ###	break
#     fi
# done

# if [ $NOT_UPDATED == 0 ];then
#     echo "** $MYHOST is up2date with OS downloads..."
#     exit 0
# fi
    
# #------------------
# # Verify the rpms
# #------------------

# echo "Verifying rpm dependencies..."

# export VERIFY=`rpm -U --ignoresize --test $RPMDIR/*.rpm 2>&1`
# PARTIAL_INSTALL=`echo $VERIFY | grep -v "is already installed"` 
# export RPM_EXTRA_OPTION=""
# export INCREMENTAL=0

# if [ "x$VERIFY" == "x" ];then
#     echo "Dependencies verified; proceeding with installation..."
#     echo " "
# elif [ "x$PARTIAL_INSTALL" == "x" ];then
#     echo " "
#     echo "Note: Partial install detected; it looks like a previous attempt"
#     echo "to install package updates was only partially successful."
#     echo " "
#     echo "Picking up from previous install...."
#     export INCREMENTAL=1
#     export RPM_EXTRA_OPTION="--replacepkgs"
# else
#     echo " "
#     echo "** Error: rpm dependencies not verified; this may mean that the"
#     echo "**        host node which downloaded the os updates differs from the"
#     echo "**        current installation target"
#     echo " "
#     echo "$VERIFY"
#     echo "partial = $PARTIAL_INSTALL"
#     exit 1
# fi

# ###exit 0

# #---------------------
# # Install the packages
# #---------------------

# # if [ $INCREMENTAL ];then
# #     echo "rpm -Uvh --ignoresize $RPM_EXTRA_OPTION $MISSING_RPMS"
# # else
# #     echo "rpm -Uvh --ignoresize $RPM_EXTRA_OPTION $RPMDIR/*.rpm"
# # fi

# rpm -Uvh --ignoresize $RPM_EXTRA_OPTION $RPMDIR/*.rpm

# exit 1

# cd $RPMDIR

# for i in `ls *.rpm`; do
# #    echo $i

#     pkg=`echo $i | perl -pe 's/(\S+).(noarch|x86_64|i386).rpm/$1/'`

# #    pkg=`echo $i | awk -F '.x86_64.rpm' '{print $1}'`

# #     if [ x"$pkg" == "x" ];then
# # 	echo "checking for noarch"
# # 	pkg=`echo $i | awk -F '.noarch.rpm' '{print $1}'`
# #     fi

# #     if [ x"$pkg" == "x" ];then
# # 	echo "checking for i386"
# # 	pkg=`echo $i | awk -F '.i386.rpm' '{print $1}'`
# #     fi
	
#     igot=`rpm -q $pkg`

#     if [ "$igot" != "$pkg" ];then
# 	echo "** Installing $pkg...."
# 	rpm -Uvh --nodeps  --ignoresize ./$i
#     fi

# done

# ###rpm -Uvh --ignoresize $RPM_EXTRA_OPTION $RPMDIR/*.rpm
# #rpm "$ROLLBACK_MACRO" --ignoresize -Uvh $RPM_EXTRA_OPTION $ROLLBACK_OPTS $RPMDIR/*.rpm



