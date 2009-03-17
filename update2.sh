#!/bin/bash
#
# $Id: update.sh,v 1.36 2008/02/04 03:20:49 karl Exp $
#
#-----------------------------------------------------------
# TACC Software Updates
# 
# Use this utility to verify that all desired TACC software
# is installed on a node and is at the correct revision.
# 
# A list of each specific rpm to monitor for various 
# appliances is included below.
#
# Ranger Version: Originally 6/21/07 - ks 
# Texas Advanced Computing Center 
#-----------------------------------------------------------

# Command-line Inputs

# Inputs -------------------

export VERBOSE=0
export UPDATE_RPMS=1

# End Inputs -------------------

export MYHOST=`hostname -s`
export RPM_DIR=/share/home/0000/build/rpms/RPMS/
export MYARCH=x86_64
export REMOTE_INSTALL_DIR=/share/home/0000/build/admin/hpc_stack/

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

. $INSTALL_DIR/node_types.sh 

#-----------------------------
# Software common to all Nodes
#-----------------------------

GLOBAL_RPMS="login-scripts:1.3-4 \
    strace:4.5.15-1.el4.1 \
    modules-base:3.1.6-9 \
    gdb:6.3.0.0-1.143.el4 \
    tacc_ib:1.0-22 \
    tacc_sysctl:1.0-4"

GLOBAL_UNINSTALL_RPMS="\
    intel9-compilers:9.1.47-3 \
    intel10-compilers:10.1.008-1 \
    mvapich-intel:0.9.9-9 \
    mvapich-intel:0.9.9-8 \
    mvapich-intel:0.9.9-10 \
    openmpi-intel:1.2.4-1 \
    sun-compilers:12-2 \
    exim:4.43-1.RHEL4.5 \
    tacc_work1_client:1.0-1 \
    "

#------------------------------------------------------------------------
# Note: Master is tasked with keeping the programs in /share in check.
# This means that any package installed into /opt/apps should be
# controlled via master and added to the following SHARED_RPMS
# list.  For testing, this same list will also be installed on
# a local (non-shared) disk on the build node.
#------------------------------------------------------------------------

SHARED_RPMS=" \
    intel10-compilers:10.1.011-3 \
    mkl10:10.0-2 \
    gotoblas:1.23-1 \
    mvapich2-intel10_1:1.0-6 \
    mvapich2-pgi7_1:1.0-6 \
    mvapich2-intel9_1:1.0-6 \
    mvapich-intel10_1:0.9.9-5 \
    mvapich-intel9_1:0.9.9-6 \
    mvapich-pgi7_1:0.9.9-4 \
    mvapich-devel-pgi7_1:0.9.9-6 \
    mvapich-devel-intel10_1:0.9.9-6 \
    mvapich-devel-intel9_1:0.9.9-6 \
    openmpi-intel9_1:1.2.4-4 \
    openmpi-pgi7_1:1.2.4-3 \
    openmpi-intel10_1:1.2.4-4 \
    fftw3-intel10_1:3.1.2-1 \
    fftw3-pgi7_1:3.1.2-3 \
    fftw2-intel10_1-mvapich1_0_9_9:2.1.5-5 \
    fftw2-intel10_1-mvapich2_1_0_1:2.1.5-5 \
    acml-intel10_1:4.0.1-1 \
    pgi:7.1-2 \
    fftw2-pgi7_1-mvapich1_0_9_9:2.1.5-5 \
    fftw2-pgi7_1-mvapich2_1_0_1:2.1.5-5 \
    netcdf-intel10_1:3.6.2-1 \
    netcdf-pgi7_1:3.6.2-1 \
    acml-pgi7_1:4.0.1-1 \
    binutils-amd:070220-6 \
    intel9-compilers:9.1.47-5 \
    hdf5-pgi7_1:1.6.5-2 \
    hdf5-intel10_1:1.6.5-1 \
    sun-compilers:12-6 \
    GSL:1.10-3 \
    petsc-pgi7_1-mvapich1_0_9_9:2.3.3-1 \
    petsc-pgi7_1-mvapich2_1_0_1:2.3.3-1 \
    petsc-pgi7_1-openmpi:2.3.3-1 \
    petsc-intel10_1-mvapich1_0_9_9:2.3.3-1 \
    petsc-intel10_1-mvapich2_1_0_1:2.3.3-1 \
    petsc-intel10_1-openmpi:2.3.3-1 \
    tao-intel10_1-mvapich1_0_9_9:1.9-1 \
    tao-intel10_1-mvapich2_1_0_1:1.9-1 \
    tao-pgi7_1-mvapich1_0_9_9:1.9-1 \
    tao-pgi7_1-mvapich2_1_0_1:1.9-1 \
    slepc-intel10_1-mvapich1_0_9_9:2.3.3-1 \
    slepc-intel10_1-mvapich2_1_0_1:2.3.3-1 \
    slepc-intel10_1-openmpi:2.3.3-1 \
    slepc-pgi7_1-mvapich1_0_9_9:2.3.3-1 \
    slepc-pgi7_1-mvapich2_1_0_1:2.3.3-1 \
    slepc-pgi7_1-openmpi:2.3.3-1 \
    papi:3.5.0-4 \
    "

# Now we define rpms local to each appliance. Recall note above that
# master is in charge of all apps in /share and therefore inherits
# from SHARED_RPMS

master_RPMS=" \
    numactl:1.0.2-0 \
    lustre:1.6.4.2-2.6.9_55.0.9.EL_TACC_lustre.1.6.3smp_200802010650 \
    lustre-modules:1.6.4.2-2.6.9_55.0.9.EL_TACC_lustre.1.6.3smp_200802010650 \
    lustre-ldiskfs:3.0.4-2.6.9_55.0.9.EL_TACC_lustre.1.6.3smp_200802010651 \
    tacc_share_client:1.0-9 \
    tacc_work_client:1.0-5 \
    tacc_scratch_client:1.0-4 \
    neon:0.24.7-4 \
    subversion:1.1.4-2.ent \
    apr:0.9.4-24.5.c4.2 \
    apr-util-devel:0.9.4-21 \
    sge-execd:6.1AR3-13 \
    gnuplot:4.0.0-4 \
    $SHARED_RPMS"

oss_RPMS=" \
    hd:1.04-1 \
    lustre-ldiskfs:3.0.2-2.6.9_55.0.9.EL_lustre.1.6.3smp \
    lustre:1.6.3-2.6.9_55.0.9.EL_lustre.1.6.3smp \
    lustre-modules:1.6.3-2.6.9_55.0.9.EL_lustre.1.6.3smp \
    e2fsprogs:1.39.cfs8-0redhat \
    mvSatalinux-tacc-1.6.3-test:3.6.3_2-2.6.9_55.0.9.EL_lustre_4 \
    tacc-udev:1-2 \
    tacc_lustre:1.0-3"

mds_RPMS=" \
    lustre-ldiskfs:3.0.2-2.6.9_55.0.9.EL_lustre.1.6.3smp \
    lustre:1.6.3-2.6.9_55.0.9.EL_lustre.1.6.3smp \
    lustre-modules:1.6.3-2.6.9_55.0.9.EL_lustre.1.6.3smp_200712031250 \
    e2fsprogs:1.39.cfs8-0redhat \
    tacc_lustre:1.0-2"

compute_RPMS=" \
    sge-execd:6.1AR3-13 \
    numactl:1.0.2-0 \
    tacc_sensors:1-8 \
    pam-sge:6.1AR3-6 \
    lustre:1.6.4.2-2.6.18.8.TACC.lustre.perfctr_200801230003 \
    lustre-modules:1.6.4.2-2.6.18.8.TACC.lustre.perfctr_200801230003 \
    lustre-ldiskfs:3.0.4-2.6.18.8.TACC.lustre.perfctr_200801230003 \
    tacc_share_client:1.0-9 \
    tacc_work_client:1.0-5 \
    tacc_scratch_client:1.0-4 \
    ibutils:1.2-0 \
    ipoibtools:1.1-0 \
    kernel-ib:1.2.5.4-2.6.18.8.TACC.lustre.perfctr \
    libibcm:1.0-1 \
    libibcommon:1.0.4-0 \
    libibmad:1.0.6-0 \
    libibumad:1.0.6-0 \
    libibverbs:1.1.1-0 \
    libibverbs-utils:1.1.1-0 \
    libmlx4:0.1-0 \
    libmthca:1.0.4-0 \
    libopensm:3.0.3-0 \
    libosmcomp:3.0.3-0 \
    libosmvendor:3.0.3-0 \
    librdmacm:1.0.2-0 \
    librdmacm-utils:1.0.2-0 \
    mstflint:1.2-0 \
    openib-diags:1.2.7-0 \
    perftest:1.2-0 \
    tvflash:0.9.0-0 \
    compute_ssh:1.0-1"

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
    numactl:1.0.2-0 \
    nxge:1.0-1 \
    tacc_share_client:1.0-9 \
    tacc_work_client:1.0-5 \
    tacc_scratch_client:1.0-4 \
    lustre:1.6.4.2-2.6.9_55.0.9.EL_TACC_lustre.1.6.3smp_200802010650 \
    lustre-modules:1.6.4.2-2.6.9_55.0.9.EL_TACC_lustre.1.6.3smp_200802010650 \
    lustre-ldiskfs:3.0.4-2.6.9_55.0.9.EL_TACC_lustre.1.6.3smp_200802010651 \
    neon:0.24.7-4 \
    subversion:1.1.4-2.ent \
    apr:0.9.4-24.5.c4.2 \
    apr-util-devel:0.9.4-21 \
    swig:1.3.21-6 \
    apr-util:0.9.4-21 \
    sge-execd:6.1AR3-13 \
    screen:4.0.2-5 \
    gnuplot:4.0.0-4 \
    "

gridftp_RPMS=" \
    nxge:1.0-1 \
    lustre:1.6.4.2-2.6.9_55.0.9.EL_TACC_lustre.1.6.3smp_200802010650 \
    lustre-modules:1.6.4.2-2.6.9_55.0.9.EL_TACC_lustre.1.6.3smp_200802010650 \
    lustre-ldiskfs:3.0.4-2.6.9_55.0.9.EL_TACC_lustre.1.6.3smp_200802010651 \
    tacc_share_client:1.0-9 \
    tacc_work_client:1.0-5 \
    tacc_scratch_client:1.0-4 \
    sge-execd:6.1AR3-13 \
    "

sge_RPMS=" \
    lustre:1.6.4.2-2.6.9_55.0.9.EL_TACC_lustre.1.6.3smp_200802010650 \
    lustre-modules:1.6.4.2-2.6.9_55.0.9.EL_TACC_lustre.1.6.3smp_200802010650 \
    lustre-ldiskfs:3.0.4-2.6.9_55.0.9.EL_TACC_lustre.1.6.3smp_200802010651 \
    tacc_share_client:1.0-9 \
    "

#-------------------
# Kernel Definitions
#-------------------

compute_KERNEL_DATE="2.6.18.8.TACC.lustre.perfctr #1 SMP Wed Jan 30 14:14:29 CST 2008"
compute_KERNEL="tacc-kernel-2.6.18.8.TACC.lustre.perfctr-7"
compute_IB_DATE="Mon 20 Aug 2007 06:14:19 PM CDT"

build_KERNEL_DATE="2.6.18.8.TACC.lustre.perfctr #2 SMP Mon Dec 10 17:14:07 CST 2007"
build_KERNEL="tacc-kernel-2.6.18.8.TACC.lustre.perfctr-6"

oss_KERNEL_DATE="2.6.9-55.0.9.EL_lustre.1.6.3smp #1 SMP Sun Oct 7 20:08:31 EDT 2007"
oss_KERNEL="kernel-lustre-smp-2.6.9-55.0.9.EL_lustre.1.6.3"

mds_KERNEL_DATE="2.6.9-55.0.9.EL_lustre.1.6.3smp #1 SMP Sun Oct 7 20:08:31 EDT 2007"
mds_KERNEL="kernel-lustre-smp-2.6.9-55.0.9.EL_lustre.1.6.3"

login_KERNEL_DATE="2.6.9-55.0.9.EL_TACC_lustre.1.6.3smp #15 SMP Fri Feb 1 06:42:28 CST 2008"
login_KERNEL="tacc-kernel-logins-2.6.955.0.9.EL_TACC_lustre.1.6.3-4"

gridftp_KERNEL_DATE="2.6.9-55.0.9.EL_TACC_lustre.1.6.3smp #15 SMP Fri Feb 1 06:42:28 CST 2008"
gridftp_KERNEL="tacc-kernel-logins-2.6.955.0.9.EL_TACC_lustre.1.6.3-4"

sge_KERNEL_DATE="2.6.9-55.0.9.EL_TACC_lustre.1.6.3smp #15 SMP Fri Feb 1 06:42:28 CST 2008"
sge_KERNEL="tacc-kernel-logins-2.6.955.0.9.EL_TACC_lustre.1.6.3-4"

master_KERNEL_DATE="2.6.9-55.0.9.EL_TACC_lustre.1.6.3smp #15 SMP Fri Feb 1 06:42:28 CST 2008"
master_KERNEL="kernel-lustre-smp-2.6.9-55.0.9.EL_lustre.1.6.3"

#-------------------------
# Function initializtion
#-------------------------

. $INSTALL_DIR/verify_rpms.sh
. $INSTALL_DIR/verify_kernel.sh

#--------------------------------
# Verify the Kernel Installation
#--------------------------------

export NEEDS_UPDATE=0

rpms_list=$BASENAME"_KERNEL_DATE"
eval local_date=\$$rpms_list

rpms_list=$BASENAME"_KERNEL"
eval local_kernel=\$$rpms_list

verify_kernel "$local_date" "$local_kernel" 

if [ "$NEEDS_UPDATE" == 1 ]; then
    echo " "
    echo "** $MYHOST needs kernel update..."
else
    echo "$MYHOST kernel is up to date (type=$BASENAME)"
fi

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

rpms_list="GLOBAL_UNINSTALL_RPMS"
eval local_rpms=\$$rpms_list
verify_rpms "$local_rpms" REMOVE

#------------------------------------------------------------
# Verify os distribution is up2date with a quick sanity check.
#------------------------------------------------------------

$INSTALL_DIR/quick_check.sh

#/usr/bin/perl /export/admin/blades/.fix/static.pl /etc/sysconfig/static-routes







