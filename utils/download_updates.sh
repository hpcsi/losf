#!/bin/bash
#
# $Id$
#
#-------------------------------------------------------------
# Utility for downloading updated OS rpms from a centralized
# mirror.
# 
# Note: node types for os-updates are defined in node_types.sh
# 
# Originally: 4-15-2007 - ks
# Texas Advanced Computing Center
#-------------------------------------------------------------

# Inputs -------------------

export SRC_DIR=/share/home/0000/build/admin/os-updates/
export NODE_QUERY=/share/home/0000/build/admin/hpc_stack/node_types.pl
export RHN_DIR=/etc/sysconfig/rhn
export IGNORE_PKGS="kernel*;libibcm*;libibcommon*;libibverbs*;libipathverbs*;libmthca*;libopensm*;libosmcomp*;libosmvendor*;librdmacm*;mstflint*;opensm*;libibumad*;openib*;ibutils*;libsdp*;iscsi-initiator-utils;infiniband-diags*;libcxgb3;bash*"

# End Inputs -------------------

echo " "
echo "------------------------------"
echo "** TACC OS-Update Downloads **" 
echo "------------------------------"

#---------------------------------
# Set correct packages to ignore 
# for local host.
#---------------------------------

/usr/bin/perl -p -i -e "s|pkgSkipList=\S*$|pkgSkipList=$IGNORE_PKGS|" $RHN_DIR/up2date

#---------------------
# Determine node type
#---------------------

. $NODE_QUERY

#---------------------------------
# Determine save location for rpms
#---------------------------------

export DATE=`date +%F`
mkdir -p $SRC_DIR/$BASENAME/$DATE
export RPMDIR=$SRC_DIR$BASENAME/$DATE
echo "Saving downloaded up2date rpms in $RPMDIR..."

#-------------------------------------------
# Save the list of currently installed rpms
#-------------------------------------------

rpm -qa >& $RPMDIR/rpms-previously-installed

#------------------
# Download the rpms
#------------------

up2date -v -u -d  --tmpdir=$RPMDIR

#----------------------------------------------------
# Generate a quick list of the rpms so that
# the quick_check script can verify that the desired
# packages are installed.
#----------------------------------------------------

cd $RPMDIR
ls *.rpm > rpm_list





