#!/bin/bash
#
# $Id$
#
#-----------------------------------------------------------
# TACC Software Updates
# 
# Utility to update individual Cluster node types to
# latest production revision (or verify node is already
# in sync).
#
# See config.global for top-level input variables.
# 
#
# Ranger Version:   Originally 6/21/07 - ks 
# Longhorn Version: 10-25-09
#
# Questions/Problems?: karl@tacc.utexas.edu
# Texas Advanced Computing Center 
#-----------------------------------------------------------

# Command-line Inputs

# Inputs -------------------

export VERBOSE=0
export UPDATE_RPMS=1

# End Inputs -------------------

export MYHOST=`hostname -s`
export RPM_DIR=/home/build/rpms/RPMS/
export MYARCH=x86_64
export REMOTE_INSTALL_DIR=/home/build/admin/hpc_stack/

#-------------------------------------
# Command-Line Options 
# Used to setup rpm install location
# for use with Rocks initiated install
#-------------------------------------

NUM_ARGS=$#
if [ $# -gt 1 -a "$1" = "ROCKS" ];then
    export SRC_DIR=$2
    export INSTALL_DIR=/tacc/tacc-sw-update
    export MODE="ROCKS"

    echo " "
    echo "** Running update.sh in ROCKS install mode"
    echo "** -> Installing from $SRC_DIR"
else
    export SRC_DIR=$RPM_DIR
    export INSTALL_DIR=$REMOTE_INSTALL_DIR
    export MODE="INTERACTIVE"
fi

#-------------------
# Query type of node
#-------------------

export NODE_TYPE_SILENT=1

RESULT=`$INSTALL_DIR/node_types | grep Node_Type | awk '{print $3}'`
CLUSTER=`echo $RESULT | awk -F : '{print $1}'`
BASENAME=`echo $RESULT | awk -F : '{print $2}'`

if [ x"$BASENAME" == "x" -o x"$CLUSTER" == "x" ];then
    echo " "
    echo "**"
    echo "** Error: unable to ascertain Cluster node type for host ($MYHOST)"
    echo "**"
    echo " "
    exit 1
else
    echo " "
    echo "Performing Updates for $CLUSTER -> $BASENAME node type"
    echo " "
fi

#-----------------------------
# Software common to all Nodes
#-----------------------------

GLOBAL_RPMS=" \
    lua:5.1.4-7 \
    lmod:2.9.4-1 \
    base-modules:2.0-1 \
    compat-libstdc++-33-3.2.3-61 \
    intel11-compilers:11.1-0 \
"

GLOBAL_UNINSTALL_RPMS="\
    "

#------------------------------------------------------------------------
# Note: Master is tasked with keeping the programs in /share in check.
# This means that any package installed into /opt/apps should be
# controlled via master and added to the following SHARED_RPMS
# list.  For testing, this same list will also be installed on
# a local (non-shared) disk on the build node.
#------------------------------------------------------------------------

SHARED_RPMS=" \
     "

# Now we define rpms local to each appliance. Recall note above that
# master is in charge of all apps in /share and therefore inherits
# from SHARED_RPMS

master_RPMS=" \
    subversion:1.4.2-4.el5_3.1 \
    tacc_login_scripts-login:2.0-26 \
    apr:1.2.7-11.el5_3.1 \
    apr-devel:1.2.7-11.el5_3.1 \
    apr-util:1.2.7-7.el5_3.2 \
    apr-util-devel:1.2.7-7.el5_3.2 \
    neon:0.25.5-10.el5 \
    $SHARED_RPMS"

oss_RPMS=" \
    "

mds_RPMS=" \
    "

compute_RPMS=" \
    "

# Special check for the build node.  Note that for testing, /share/apps
# on the build node maps to a local file system on build.  Otherwise, build
# is treated as a regular compute node.  

if [ "$MYHOST" == "build" ];then
    echo " "
    echo "** Important note for build"
    echo "** --> Installing apps in local /share/apps for testing"
    echo " "
    compute_RPMS="$compute_RPMS $SHARED_RPMS"
fi

login_RPMS=" \
    subversion:1.4.2-4.el5_3.1 \
    tacc_login_scripts-login:2.0-26 \
    apr:1.2.7-11.el5_3.1 \
    apr-devel:1.2.7-11.el5_3.1 \
    apr-util:1.2.7-7.el5_3.2 \
    apr-util-devel:1.2.7-7.el5_3.2 \
    neon:0.25.5-10.el5 \
    intel-licenses:1.0-1 \
    "

sge_RPMS=" \
    lustre-ldiskfs:3.0.6-2.6.9_67.0.22.EL_lustre.1.6.6smp_200812020703 \
    lustre-modules:1.6.6-2.6.9_67.0.22.EL_lustre.1.6.6smp_200812020702 \
    lustre:1.6.6-2.6.9_67.0.22.EL_lustre.1.6.6smp_200812020702 \
    tacc_share_client:1.0-14 \
    "
#-------------------
# Kernel Definitions
#-------------------

compute_KERNEL_DATE="2.6.18.8.TACC.lustre.perfctr #4 SMP Tue Jul 22 07:16:12 CDT 2008"
compute_KERNEL="tacc-kernel-2.6.18.8.TACC.lustre.perfctr-9"
compute_IB_DATE="Mon 20 Aug 2007 06:14:19 PM CDT"

build_KERNEL_DATE="2.6.18.8.TACC.lustre.perfctr #2 SMP Mon Dec 10 17:14:07 CST 2007"
build_KERNEL="tacc-kernel-2.6.18.8.TACC.lustre.perfctr-6"

oss_KERNEL_DATE="2.6.9-55.0.9.EL_lustre.1.6.3smp #1 SMP Sun Oct 7 20:08:31 EDT 2007"
oss_KERNEL="kernel-lustre-smp-2.6.9-55.0.9.EL_lustre.1.6.3"

mds_KERNEL_DATE="2.6.9-55.0.9.EL_lustre.1.6.3smp #1 SMP Sun Oct 7 20:08:31 EDT 2007"
mds_KERNEL="kernel-lustre-smp-2.6.9-55.0.9.EL_lustre.1.6.3"

login_KERNEL_DATE="2.6.9-78.0.22.EL_lustre_TACC #2 SMP Mon Sep 21 15:12:44 CDT 2009"
login_KERNEL="kernel-2.6.978.0.22.EL_lustre_TACC-1"

sge_KERNEL_DATE="2.6.9-67.0.22.EL_lustre.1.6.6smp #1 SMP Thu Sep 11 18:59:03 EDT 2008"
sge_KERNEL="kernel-lustre-smp-2.6.9-67.0.22.EL_lustre.1.6.6"

master_KERNEL_DATE="2.6.9-78.0.22.EL_lustre_TACC #2 SMP Mon Sep 21 15:12:44 CDT 2009"
master_KERNEL="kernel-2.6.978.0.22.EL_lustre_TACC-1"

#-------------------------
# Function initializtion
#-------------------------

. $INSTALL_DIR/utils/verify_rpms.sh
. $INSTALL_DIR/utils/verify_kernel.sh

#--------------------------------
# Verify the Kernel Installation
#--------------------------------

# export NEEDS_UPDATE=0

# rpms_list=$BASENAME"_KERNEL_DATE"
# eval local_date=\$$rpms_list

# rpms_list=$BASENAME"_KERNEL"
# eval local_kernel=\$$rpms_list

# verify_kernel "$local_date" "$local_kernel" 

# if [ "$NEEDS_UPDATE" == 1 ]; then
#     echo " "
#     echo "** $MYHOST needs kernel update..."
# else
#     echo "$MYHOST kernel is up to date (type=$BASENAME)"
# fi

#--------------------------------------
# Install software common to all nodes.
#--------------------------------------

export NEEDS_UPDATE=0
export count=0

verify_rpms "$GLOBAL_RPMS"

if [ "$NEEDS_UPDATE" == 1 ]; then
    echo " "
    echo "** $MYHOST needs updating (type=common)"
else
    printf "$MYHOST is up to date with %3i packages (type=common)\n" $count 
fi

#------------------------------------------------
# Install software common to this appliance only
#------------------------------------------------

export NEEDS_UPDATE=0
export count=0
rpms_list=$BASENAME"_RPMS"
eval local_rpms=\$$rpms_list

verify_rpms "$local_rpms" UPDATE

if [ "$NEEDS_UPDATE" == 1 ]; then
    echo " "
    echo "** $MYHOST needs updating ($BASENAME packages)"
else
    printf "$MYHOST is up to date with %3i packages (type=$BASENAME)\n" $count 
fi

#-----------------------------------------------
# Verify the *non*-existence of certain key rpms
#-----------------------------------------------

##### rpms_list="GLOBAL_UNINSTALL_RPMS"
##### eval local_rpms=\$$rpms_list
##### verify_rpms "$local_rpms" REMOVE

#------------------------------------------------------------
# Verify os distribution is up2date with a quick sanity check.
#------------------------------------------------------------

##### $INSTALL_DIR/quick_check.sh








