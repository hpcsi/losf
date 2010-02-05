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
###    export INSTALL_DIR=/tacc/tacc-sw-update
    export INSTALL_DIR=/home/build/admin/hpc_stack
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

    shell_startup:1.4.1-1 \
    lmod:2.9.6-1 \
    tcsh:6.16-2 \
    ksh:20091021-1 \
    zsh:4.3.9-1
    bash:3.2.48-1

    base-modules:2.0-3 \
    tacc_sysctl:1.0-7 \
    compat-libstdc++-33:3.2.3-61.i386 \
    compat-libstdc++-33:3.2.3-61.x86_64 \
    libsmbios:2.2.19-10.1.el5.x86_64 \
    gdb:6.8-37.el5 \
    tacc_ib:1.0-0 \
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

    intel11-compilers:11.1-0 \

    subversion:1.4.2-4.el5_3.1 \
    tacc_login_scripts-login:2.0-31 \
    apr:1.2.7-11.el5_3.1 \
    apr-devel:1.2.7-11.el5_3.1 \
    apr-util:1.2.7-7.el5_3.2 \
    apr-util-devel:1.2.7-7.el5_3.2 \
    neon:0.25.5-10.el5 \

    lustre:1.8.1.1-2.6.18_128.7.1_lustre_perfctr_TACC_201001041749 \
    lustre-modules:1.8.1.1-2.6.18_128.7.1_lustre_perfctr_TACC_201001041749 \

    mkl:10.2.2.025-0 \
    mvapich2-intel11_1:1.4-3 \
    tightvnc:1.3.10-1 \
    tacc_scratch_client:1.0-5 \
    git:1.6.5.7-1 \

    $SHARED_RPMS"

oss_RPMS=" \
    sysstat:7.0.2-3.el5 \
    ibutils:1.2-1.ofed1.4.2 \
    infiniband-diags:1.4.4_20090314-1.ofed1.4.2 \
    kernel-ib:1.4.2-2.6.18_128.7.1_lustre_perfctr_TACC \
    libibcm:1.0.4-1.ofed1.4.2 \
    libibcommon:1.1.2_20090314-1.ofed1.4.2 \
    libibmad:1.2.3_20090314-1.ofed1.4.2 \
    libibumad:1.2.3_20090314-1.ofed1.4.2 \
    libibverbs:1.1.2-1.ofed1.4.2 \
    libibverbs-utils:1.1.2-1.ofed1.4.2 \
    libmlx4:1.0-1.ofed1.4.2 \
    libmthca:1.0.5-1.ofed1.4.2 \
    librdmacm:1.0.8-1.ofed1.4.2 \
    librdmacm-utils:1.0.8-1.ofed1.4.2 \
    mstflint:1.4-1.ofed1.4.2 \
    ofed-docs:1.4.2-0 \
    ofed-scripts:1.4.2-0 \
    opensm-libs:3.2.6_20090317-1.ofed1.4.2 \
    perftest:1.2-1.ofed1.4.2 \
    qperf:0.4.6-1.ofed1.4.2 \
    tvflash:0.9.0-1.ofed1.4.2 \

    lustre:1.6.7.50-2.6.18_128.7.1_lustre_perfctr_TACC_201001061130 \
    lustre-modules:1.6.7.50-2.6.18_128.7.1_lustre_perfctr_TACC_201001061130 \
    lustre-ldiskfs:3.0.9-2.6.18_128.7.1_lustre_perfctr_TACC_201001061130 \

    tacc-udev-md1000:1-6 \
    e2fsprogs:1.41.6.sun1-0redhat \
    tacc_lustre:1.0-2 \
    "

#    lustre:1.8.1.59-2.6.18_128.7.1_lustre_perfctr_TACC_201001052046 \
#    lustre-modules:1.8.1.59-2.6.18_128.7.1_lustre_perfctr_TACC_201001052046 \
#    lustre-ldiskfs:3.0.9-2.6.18_128.7.1_lustre_perfctr_TACC_201001052047 \

#    lustre:1.8.1.1-2.6.18_128.7.1_lustre_perfctr_TACC_200910242243 \
#    lustre-modules:1.8.1.1-2.6.18_128.7.1_lustre_perfctr_TACC_200910242243 \
#    lustre-ldiskfs:3.0.9-2.6.18_128.7.1_lustre_perfctr_TACC_200910242244 \

mds_RPMS=" \
    sysstat:7.0.2-3.el5 \
    ibutils:1.2-1.ofed1.4.2 \
    infiniband-diags:1.4.4_20090314-1.ofed1.4.2 \
    kernel-ib:1.4.2-2.6.18_128.7.1_lustre_perfctr_TACC \
    libibcm:1.0.4-1.ofed1.4.2 \
    libibcommon:1.1.2_20090314-1.ofed1.4.2 \
    libibmad:1.2.3_20090314-1.ofed1.4.2 \
    libibumad:1.2.3_20090314-1.ofed1.4.2 \
    libibverbs:1.1.2-1.ofed1.4.2 \
    libibverbs-utils:1.1.2-1.ofed1.4.2 \
    libmlx4:1.0-1.ofed1.4.2 \
    libmthca:1.0.5-1.ofed1.4.2 \
    librdmacm:1.0.8-1.ofed1.4.2 \
    librdmacm-utils:1.0.8-1.ofed1.4.2 \
    mstflint:1.4-1.ofed1.4.2 \
    ofed-docs:1.4.2-0 \
    ofed-scripts:1.4.2-0 \
    opensm-libs:3.2.6_20090317-1.ofed1.4.2 \
    perftest:1.2-1.ofed1.4.2 \
    qperf:0.4.6-1.ofed1.4.2 \
    tvflash:0.9.0-1.ofed1.4.2 \

    lustre:1.6.7.50-2.6.18_128.7.1_lustre_perfctr_TACC_201001061130 \
    lustre-modules:1.6.7.50-2.6.18_128.7.1_lustre_perfctr_TACC_201001061130 \
    lustre-ldiskfs:3.0.9-2.6.18_128.7.1_lustre_perfctr_TACC_201001061130 \

    tacc-udev-mds:1-0 \
    e2fsprogs:1.41.6.sun1-0redhat \
    "

compute_and_login_RPMS=" \

    intel11-compilers:11.1-0 \
    mkl:10.2.2.025-0 \
    mvapich2-intel11_1:1.4-4 \
    mvapich2-debug-intel11_1:1.4-1 \
    openmpi-intel11_1:1.3.3-4 \

    hdf5-intel11_1-mvapich2_1_4:1.8.3-9 \
    silo:4.6.2-1 \
    netcdf-intel11_1:4.0.1-1 \
    fftw2-intel11_1-openmpi_1_3_3:2.1.5-1 \
    fftw2-intel11_1-mvapich2_1_4:2.1.5-1 \

    cuda:2.2-0 \
    cuda_SDK:2.2-1 \
    paraview-intel11_1-openmpi_1_3_3:3.6.1-1 \
    paraview-intel11_1-mvapich2_1_4:3.6.1-1 \
    visit-intel11_1-openmpi_1_3_3:1.12.0-1 \
    visit-intel11_1-mvapich2_1_4:1.12.0-1 \

    sge-execd-6.2:6.2u4-1 \
    tacc_scratch_client:1.0-5 \
    tacc_ranger_fs:1.0-2 \
    ensight-gold:9.0-0 \
    libXp:1.0.0-8.1.el5 \
    libXp-devel:1.0.0-8.1.el5 \
    sas:9.2-1 \
    "
    

compute_RPMS=" \
    tacc_login_scripts-compute:2.0-31 \
    compute_ssh:1.0-4 \

    ibutils:1.2-1.ofed1.4.2 \
    infiniband-diags:1.4.4_20090314-1.ofed1.4.2 \
    kernel-ib:1.4.2-2.6.18_128.7.1_lustre_perfctr_TACC \
    libibcm:1.0.4-1.ofed1.4.2 \
    libibcommon:1.1.2_20090314-1.ofed1.4.2 \
    libibmad:1.2.3_20090314-1.ofed1.4.2 \
    libibumad:1.2.3_20090314-1.ofed1.4.2 \
    libibverbs:1.1.2-1.ofed1.4.2 \
    libibverbs-utils:1.1.2-1.ofed1.4.2 \
    libmlx4:1.0-1.ofed1.4.2 \
    libmthca:1.0.5-1.ofed1.4.2 \
    librdmacm:1.0.8-1.ofed1.4.2 \
    librdmacm-utils:1.0.8-1.ofed1.4.2 \
    mstflint:1.4-1.ofed1.4.2 \
    ofed-docs:1.4.2-0 \
    ofed-scripts:1.4.2-0 \
    opensm-libs:3.2.6_20090317-1.ofed1.4.2 \
    perftest:1.2-1.ofed1.4.2 \
    qperf:0.4.6-1.ofed1.4.2 \
    tvflash:0.9.0-1.ofed1.4.2 \

    lustre:1.6.7.50-2.6.18_128.7.1_lustre_perfctr_TACC_201001061130 \
    lustre-modules:1.6.7.50-2.6.18_128.7.1_lustre_perfctr_TACC_201001061130 \

    VirtualGL:2.1.3-20090625 \
    tightvnc:1.3.10-1 \
    turbojpeg:1.11-20081028 \
    tacc_visnode:1.0-2 \
    startvnc:1.0-2 \
    vnc-server:4.1.2-14.el5_3.1 \
    qt:4.5.3-1 \
    freeglut:2.4.0-7.1.el5 \
    vtk:5.4.2-1 \
    gimp:2.2.13-2.0.7.el5 \
    gimp-libs:2.2.13-2.0.7.el5 \
    gtkhtml2:2.11.0-3 \

    intel-licenses:1.0-1 \
    $compute_and_login_RPMS
    "

#    lustre:1.8.1.1-2.6.18_128.7.1_lustre_perfctr_TACC_201001041749 \
#    lustre-modules:1.8.1.1-2.6.18_128.7.1_lustre_perfctr_TACC_201001041749 \

#    lustre:1.8.1.59-2.6.18_128.7.1_lustre_perfctr_TACC_201001052046 \
#    lustre-modules:1.8.1.59-2.6.18_128.7.1_lustre_perfctr_TACC_201001052046 \

#    lustre:1.8.1.1-2.6.18_128.7.1_lustre_perfctr_TACC_201001041749 \
#    lustre-modules:1.8.1.1-2.6.18_128.7.1_lustre_perfctr_TACC_201001041749 \

phat_RPMS="$compute_RPMS"

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
    git:1.6.5.7-1 \
    tacc_login_scripts-login:2.0-31 \
    apr:1.2.7-11.el5_3.1 \
    apr-devel:1.2.7-11.el5_3.1 \
    apr-util:1.2.7-7.el5_3.2 \
    apr-util-devel:1.2.7-7.el5_3.2 \
    tacc_httpd_config:1.0-2 \

    intel-licenses:1.0-1 \
    cmake:2.6.4-1 \
    vtk:5.4.2-1 \
    tightvnc:1.3.10-1 \
    php-gd:5.1.6-24.el5_4.5 \
    php-soap:5.1.6-24.el5_4.5 \

    lustre:1.8.1.1-2.6.18_128.7.1_lustre_perfctr_TACC_201001041749 \
    lustre-modules:1.8.1.1-2.6.18_128.7.1_lustre_perfctr_TACC_201001041749 \
    
    tacc_longhorn_port_forwarding:1.0-3 \

    $compute_and_login_RPMS \
    "

sge_RPMS=" \
    tacc_login_scripts-compute:2.0-29 \

    ibutils:1.2-1.ofed1.4.2 \
    infiniband-diags:1.4.4_20090314-1.ofed1.4.2 \
    kernel-ib:1.4.2-2.6.18_128.7.1_lustre_perfctr_TACC \
    libibcm:1.0.4-1.ofed1.4.2 \
    libibcommon:1.1.2_20090314-1.ofed1.4.2 \
    libibmad:1.2.3_20090314-1.ofed1.4.2 \
    libibumad:1.2.3_20090314-1.ofed1.4.2 \
    libibverbs:1.1.2-1.ofed1.4.2 \
    libibverbs-utils:1.1.2-1.ofed1.4.2 \
    libmlx4:1.0-1.ofed1.4.2 \
    libmthca:1.0.5-1.ofed1.4.2 \
    librdmacm:1.0.8-1.ofed1.4.2 \
    librdmacm-utils:1.0.8-1.ofed1.4.2 \
    mstflint:1.4-1.ofed1.4.2 \
    ofed-docs:1.4.2-0 \
    ofed-scripts:1.4.2-0 \
    opensm-libs:3.2.6_20090317-1.ofed1.4.2 \
    perftest:1.2-1.ofed1.4.2 \
    qperf:0.4.6-1.ofed1.4.2 \
    "
#-------------------
# Kernel Definitions
#-------------------

#compute_KERNEL_DATE="2.6.18-128.7.1_lustre_perfctr_TACC #3 SMP Wed Oct 28 10:48:56 CDT 2009"
compute_KERNEL_DATE="2.6.18-128.7.1_lustre_perfctr_TACC #4 SMP Wed Jan 6 11:52:50 CST 2010"
compute_KERNEL="tacc-kernel-2.6.18128.7.1_lustre_perfctr_TACC-3"

phat_KERNEL_DATE=$compute_KERNEL_DATE
phat_KERNEL=$compute_KERNEL

compute_IB_DATE="Mon 20 Aug 2007 06:14:19 PM CDT"

build_KERNEL_DATE="2.6.18.8.TACC.lustre.perfctr #2 SMP Mon Dec 10 17:14:07 CST 2007"
build_KERNEL="tacc-kernel-2.6.18.8.TACC.lustre.perfctr-6"

#oss_KERNEL_DATE="2.6.18-128.7.1_lustre_perfctr_TACC #3 SMP Wed Oct 28 10:48:56 CDT 2009"
oss_KERNEL_DATE="2.6.18-128.7.1_lustre_perfctr_TACC #4 SMP Wed Jan 6 11:52:50 CST 2010"
oss_KERNEL="tacc-kernel-2.6.18128.7.1_lustre_perfctr_TACC-3"

#mds_KERNEL_DATE="2.6.18-128.7.1_lustre_perfctr_TACC #3 SMP Wed Oct 28 10:48:56 CDT 2009"
mds_KERNEL_DATE="2.6.18-128.7.1_lustre_perfctr_TACC #4 SMP Wed Jan 6 11:52:50 CST 2010"
mds_KERNEL="tacc-kernel-2.6.18128.7.1_lustre_perfctr_TACC-3"

login_KERNEL_DATE="2.6.18-128.7.1_lustre_perfctr_TACC #3 SMP Wed Oct 28 10:48:56 CDT 2009"
login_KERNEL="tacc-kernel-2.6.18128.7.1_lustre_perfctr_TACC-1"

sge_KERNEL_DATE="2.6.18-128.7.1_lustre_perfctr_TACC #3 SMP Wed Oct 28 10:48:56 CDT 2009"
sge_KERNEL="tacc-kernel-2.6.18128.7.1_lustre_perfctr_TACC-1"

master_KERNEL_DATE="2.6.18-128.7.1_lustre_perfctr_TACC #3 SMP Wed Oct 28 10:48:56 CDT 2009"
master_KERNEL="tacc-kernel-2.6.18128.7.1_lustre_perfctr_TACC-1"

#-------------------------
# Function initializtion
#-------------------------

. $INSTALL_DIR/utils/verify_rpms.sh
. $INSTALL_DIR/utils/verify_kernel.sh

#--------------------------------
# Verify the Kernel Installation
#--------------------------------

export NEEDS_UPDATE=0

rpms_list=$BASENAME"_KERNEL_DATE"
eval local_date=\$$rpms_list

rpms_list=$BASENAME"_KERNEL"
eval local_kernel=\$$rpms_list
GRUB_DIR=$REMOTE_INSTALL_DIR/grub_files/$CLUSTER/$BASENAME

verify_kernel "$local_date" "$local_kernel" "$GRUB_DIR"

if [ "$NEEDS_UPDATE" == 1 ]; then
    echo " "
    echo "** $MYHOST needs kernel update..."
else
    echo "$MYHOST kernel is up to date (type=$BASENAME)"
fi

#-----------------------------------------------
# Verify the *non*-existence of certain key rpms
#-----------------------------------------------

if [ "$BASENAME" != "master" ];then
    rpms_list="GLOBAL_UNINSTALL_RPMS"
    eval local_rpms=\$$rpms_list
    verify_rpms "$local_rpms" REMOVE
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


#------------------------------------------------
# Sync desired configuration files
#------------------------------------------------

export OSF_ECHO_MODE="ERROR"

$INSTALL_DIR/sync_config_files

#------------------------------------------------------------
# Verify os distribution is up2date with a quick sanity check.
#------------------------------------------------------------

# TODO: need to update...
####$INSTALL_DIR/utils/quick_check.sh








