#!/bin/bash
#
# $Id$
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

GLOBAL_RPMS=" \
    tacc_ib:1.0-27 \
    tacc_sysctl:1.0-5"

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
    login-scripts:1.3-28 \
    tacc_login_scripts:2.0-10 \
    shell_startup:1.2-1 \
    tacc_login_scripts:2.0-5 \
    tacc_login_scripts-compute:2.0-19 \
    tacc_login_scripts-login:2.0-18 \
    "

#    tcsh:6.16-2 \
#    zsh:4.3.9-1 \
#    bash:3.2.48-1 \

#------------------------------------------------------------------------
# Note: Master is tasked with keeping the programs in /share in check.
# This means that any package installed into /opt/apps should be
# controlled via master and added to the following SHARED_RPMS
# list.  For testing, this same list will also be installed on
# a local (non-shared) disk on the build node.
#------------------------------------------------------------------------

SHARED_RPMS=" \
    git:1.5.3.8-2 \
    ddt:2.2-5 \
    intel10-compilers:10.1.011-3 \
    mkl10:10.0-2 \
    gotoblas:1.23-1 \
    mvapich2-intel10_1:1.0-6 \
    mvapich2-pgi7_1:1.0-6 \
    mvapich2-intel9_1:1.0-6 \
    mvapich-intel10_1:0.9.9-5 \
    mvapich-intel9_1:0.9.9-6 \
    mvapich-pgi7_1:0.9.9-4 \
    mvapich-devel-intel10_1:1.0-1 \
    mvapich-devel-intel9_1:1.0-1 \
    mvapich-devel-pgi7_1:1.0-1 \
    openmpi-intel9_1:1.2.4-4 \
    openmpi-pgi7_1:1.2.4-3 \
    openmpi-intel10_1:1.2.4-4 \
    fftw3-intel10_1:3.1.2-4 \
    fftw3-pgi7_1:3.1.2-4 \
    fftw2-intel10_1-mvapich1_0_9_9:2.1.5-5 \
    fftw2-intel10_1-mvapich2_1_0_1:2.1.5-5 \
    acml-intel10_1:4.0.1-1 \
    pgi:7.1-2 \
    fftw2-pgi7_1-mvapich1_0_9_9:2.1.5-6 \
    fftw2-pgi7_1-mvapich2_1_0_1:2.1.5-6 \
    netcdf-intel10_1:3.6.2-3 \
    netcdf-pgi7_1:3.6.2-3 \
    netcdf-intel9_1:3.6.2-3 \
    acml-pgi7_1:4.0.1-1 \
    binutils-amd:070220-6 \
    intel9-compilers:9.1.47-5 \
    hdf5-pgi7_1:1.6.5-2 \
    hdf5-intel10_1:1.6.5-1 \
    sun-compilers:12-6 \
    GSL:1.10-3 \
    petsc-intel10_1-mvapich1_0_9_9:2.3.3-9 \
    petsc-intel10_1-mvapich2_1_0_1:2.3.3-6 \
    petsc-intel10_1-openmpi:2.3.3-6 \
    petsc-pgi7_1-mvapich1_0_9_9:2.3.3-12 \
    petsc-pgi7_1-mvapich2_1_0_1:2.3.3-12 \
    petsc-pgi7_1-openmpi:2.3.3-5 \
    petsc-intel10_1-mvapich_devel_1_0:2.3.3-7 \
    tao-intel10_1-mvapich1_0_9_9:1.9-1 \
    tao-intel10_1-mvapich2_1_0_1:1.9-1 \
    tao-pgi7_1-mvapich1_0_9_9:1.9-1 \
    tao-pgi7_1-mvapich2_1_0_1:1.9-1 \

    slepc-intel10_1-mvapich1_0_9_9:2.3.3-3 \
    slepc-intel10_1-mvapich2_1_0_1:2.3.3-3 \
    slepc-intel10_1-openmpi:2.3.3-1 \
    slepc-pgi7_1-mvapich1_0_9_9:2.3.3-3 \
    slepc-pgi7_1-mvapich2_1_0_1:2.3.3-3 \
    slepc-pgi7_1-openmpi:2.3.3-1 \

    papi:3.5.0-5 \
    papi:3.6.0-3 \
    hypre-2.0.0-intel10_1-mvapich1_0_9_9:2.0.0-2 \
    hypre-2.0.0-intel10_1-mvapich2_1_0_1:2.0.0-2 \
    hypre-2.0.0-intel10_1-openmpi_1_2_4:2.0.0-2 \
    hypre-2.2.0b-intel10_1-mvapich1_0_9_9:2.2.0b-2 \
    hypre-2.2.0b-intel10_1-mvapich2_1_0_1:2.2.0b-2 \
    hypre-2.2.0b-intel10_1-openmpi_1_2_4:2.2.0b-2 \
    hypre-2.0.0-pgi7_1-mvapich1_0_9_9:2.0.0-4 \
    hypre-2.0.0-pgi7_1-mvapich2_1_0_1:2.0.0-4 \
    hypre-2.0.0-pgi7_1-openmpi_1_2_4:2.0.0-4 \
    hypre-2.2.0b-pgi7_1-mvapich1_0_9_9:2.2.0b-3 \
    hypre-2.2.0b-pgi7_1-mvapich2_1_0_1:2.2.0b-3 \
    hypre-2.2.0b-intel10_1-mvapich_devel_1_0:2.2.0b-3 \
    launcher:1.3-2 \
    nco-intel10_1:3.9.5-1 \
    nco-pgi7_1:3.9.5-1 \
    ncl_ncarg-pgi7_1:5.0.0-1 \
    ncl_ncarg-intel9_1:5.0.0-1 \
    ncl_ncarg-intel10_1:5.0.0-1 \
    metis-intel10_1:4.0-4 \
    metis-intel9_1:4.0-4 \
    metis-pgi7_1:4.0-4 \
    lua:5.1.4-2 \
    lmod:2.8.8-2 \
    scalapack-intel10_1-mvapich1_1_0:1.8.0-3 \
    scalapack-pgi7_1-mvapich1_1_0:1.8.0-3 \
    scalapack-intel10_1-mvapich2_1_0_1:1.8.0-3 \
    autodock-intel10_1:4.0.1-1 \
    autodock-pgi7_1:4.0.1-1 \
    python:2.5.2-1
    tau-intel10_1-mvapich1_1_0:2.17-2 \
    tau-pgi7_1-mvapich1_1_0:2.17-1 \
    kojak-intel10_1-mvapich1_1_0:2.2-3
    pdtoolkit-intel10_1-mvapich1_1_0:3.12-2
    gcc:4.2.0-3 \

    mpiblast-intel10_1-mvapich1_1_0:1.5.0-1 \
    mpiblast-intel10_1-mvapich2_1_0_1:1.5.0-1 \

    hmmer-intel10_1-openmpi_1_2_4:2.3.2_MPI_0.91-2.3 \
    hmmer-intel10_1:2.3.2-2.3 \
    hmmer-pgi7_1:2.3.2-2.3 \

    ipm-intel10_1-mvapich_devel_1_0:0.922-5 \
    ipm-intel10_1-mvapich2_1_0_1:0.922-5 \
    ipm-pgi7_1-mvapich2_1_0_1:0.922-5 \
    ipm-pgi7_1-mvapich_devel_1_0:0.922-5 \
     "

### deal with these bastards...

#    mvapich-pgi7_1:1.0.1-1 \
#    mvapich-intel9_1:1.0.1-1 \

# Now we define rpms local to each appliance. Recall note above that
# master is in charge of all apps in /share and therefore inherits
# from SHARED_RPMS

master_RPMS=" \
    login-scripts:1.3-28 \
    numactl:1.0.2-0 \
    lustre-ldiskfs:3.0.4-2.6.9_67.0.7.EL_lustre.1.6.5.1smp_200808031159 \
    lustre-modules:1.6.5.1-2.6.9_67.0.7.EL_lustre.1.6.5.1smp_200808031159 \
    lustre:1.6.5.1-2.6.9_67.0.7.EL_lustre.1.6.5.1smp_200808031159 \
    tacc_share_client:1.0-9 \
    tacc_work_client:1.0-5 \
    tacc_scratch_client:1.0-4 \
    neon:0.24.7-4 \
    subversion:1.1.4-2.ent \
    apr-util-devel:0.9.4-21 \
    sge-execd:6.1AR3-21 \
    gnuplot:4.0.0-4 \
    $SHARED_RPMS"

oss_RPMS=" \
    login-scripts:1.3-28 \
    hd:1.04-1 \
    lustre-ldiskfs:3.0.2-2.6.9_55.0.9.EL_lustre.1.6.3smp \
    lustre:1.6.3-2.6.9_55.0.9.EL_lustre.1.6.3smp \
    lustre-modules:1.6.3-2.6.9_55.0.9.EL_lustre.1.6.3smp \
    e2fsprogs:1.39.cfs8-0redhat \
    mvSatalinux-tacc-1.6.3-test:3.6.3_2-2.6.9_55.0.9.EL_lustre_4 \
    tacc-udev:1-2 \
    tacc_lustre:1.0-3"

mds_RPMS=" \
    login-scripts:1.3-13 \
    lustre-ldiskfs:3.0.2-2.6.9_55.0.9.EL_lustre.1.6.3smp \
    lustre:1.6.3-2.6.9_55.0.9.EL_lustre.1.6.3smp \
    lustre-modules:1.6.3-2.6.9_55.0.9.EL_lustre.1.6.3smp_200712031250 \
    e2fsprogs:1.39.cfs8-0redhat \
    tacc_lustre:1.0-2"

compute_RPMS=" \

    tcsh:6.16-1 \
    zsh:4.3.6-1 \
    bash:3.0-19.6 \
    login-scripts:1.3-27 \

    modules-base:3.1.6-17 \
    gdb:6.3.0.0-1.153.el4_6.2 \
    strace:4.5.15-1.el4.1 \
    sge-execd:6.2-6.2u3-4 \
    numactl:1.0.2-0 \
    tacc_outage:1.0-20 \
    tacc_outage2:2.0-4 \
    tacc_ping:1.0-1 \
    tacc_sensors:1-16 \
    pam-sge:6.2u3-2 \
    lustre-modules:1.6.7-2.6.18.8.TACC.lustre.perfctr_200903111440 \
    lustre:1.6.7-2.6.18.8.TACC.lustre.perfctr_200903111440 \
    lustre-ldiskfs:3.0.4-2.6.18.8.TACC.lustre.perfctr_200810031751 \
    tacc_share_client:1.0-14 \
    tacc_work_client:1.0-11 \
    tacc_scratch_client:1.0-11 \
    ibutils:1.2-0 \
    ipoibtools:1.1-0 \
    kernel-ib:1.3.1-2.6.18.8.TACC.lustre.perfctr \
    libibcm:1.0.2-1.ofed1.3.1 \
    libibcommon:1.0.8-1.ofed1.3.1 \
    libibmad:1.1.6-1.ofed1.3.1 \
    libibumad:1.1.7-1.ofed1.3.1 \
    libibverbs:1.1.1-1.ofed1.3.1 \
    libibverbs-utils:1.1.1-1.ofed1.3.1 \
    libmlx4:1.0-1.ofed1.3.1 \
    libmthca:1.0.4-1.ofed1.3.1 \
    libopensm:3.0.3-0 \
    libosmcomp:3.0.3-0 \
    libosmvendor:3.0.3-0 \
    librdmacm:1.0.7-1.ofed1.3.1 \
    librdmacm-utils:1.0.7-1.ofed1.3.1 \
    mstflint:1.2-0 \
    openib-diags:1.2.7-0 \
    perftest:1.2-0 \
    tvflash:0.9.0-0 \
    compute_ssh:1.0-1 \

    setup:2.5.37-1.7 \
    MySQL-python:1.2.1_p2-1.el4.1 \

    bash_tacc_test:3.2.48-2 \
    tcsh_tacc_test:6.16-3 \
    zsh_tacc_test:4.3.9-3 \

    tacc_411:1.0-1 \
    tacc_login_scripts-compute:2.0-23 \
    xorg-x11-deprecated-libs:6.8.2-1.EL.52 \
    "

#    tcsh:6.16-1 \
#    zsh:4.3.6-1 \
#    tacc_login_scripts:2.0-5 \

# the 4 below work ok with old modules...
#    tcsh:6.16-1 \
#    zsh:4.3.6-1 \
#    bash:3.0-19.6 \
#    login-scripts:1.3-27 \

# 8/09 - second verse, same as the first; 
# backing out new shell stuff for scalability issues on 
# shared fs.

###    bash:3.2.48-1 \
###    tcsh:6.16-2 \
###    zsh:4.3.9-1 \
###    tacc_login_scripts-compute:2.0-19 \



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
    modules-base:3.1.6-17 \
    taccinfo:1.0-9 \
    numactl:1.0.2-0 \
    nxge:1.1-5 \
    tacc_share_client:1.0-16 \
    tacc_work_client:1.0-14 \
    tacc_scratch_client:1.0-14 \
    tacc_corral:1.0-2 \
    lustre-ldiskfs:3.0.7.1-2.6.9_78.0.22.EL_lustre_TACC_200909211449 \
    lustre:1.6.7.2-2.6.9_78.0.22.EL_lustre_TACC_200909211439 \
    lustre-modules:1.6.7.2-2.6.9_78.0.22.EL_lustre_TACC_200909211439 \
    neon:0.24.7-4 \
    subversion:1.1.4-2.ent \
    swig:1.3.21-6 \
    sge-execd:6.2-6.2u3-4 \
    screen:4.0.2-5 \
    flex:2.5.4a-33 \
    perl-Error:0.17012-1.el4.rf \
    git-core:1.5.2.1-2.el4 \
    perl-Git:1.5.2.1-2.el4 \
    readline-devel:4.3-13 \
    pygtk2-devel:2.4.0-2.el4 \
    tk-devel:8.4.7-3.el4_6.1 \

    ploticus:2.33-1.el4.rf \
    scons:1.1.0-1 \
    ctags:5.5.4-1 \

    umb-scheme:3.2-36.EL4 \
    guile:1.6.4-14 \
    guile-devel:1.6.4-14 \

    tcsh:6.16-1 \
    zsh:4.3.6-1 \
    tacc_login_scripts-login:2.0-16 \
    login-scripts:1.3-27 \
    "

#    bash:3.2.48-1 \
#    tcsh:6.16-2 \
#    zsh:4.3.9-1 \
#    tacc_login_scripts-login:2.0-18 \

#    zsh_tacc_test:4.3.9-1 \
#    bash_tacc_test:3.2.48-1 \
#    tcsh_tacc_test:6.16-2 \

vis_RPMS=" \

    tcsh:6.16-1 \
    zsh:4.3.6-1 \
    bash:3.0-19.6 \
    login-scripts:1.3-27 \
    tacc_login_scripts-compute:2.0-16 \


    modules-base:3.1.6-17 \
    numactl:1.0.2-0 \
    tacc_share_client:1.0-15 \
    tacc_work_client:1.0-12 \
    tacc_scratch_client:1.0-12 \
    lustre-ldiskfs:3.0.7-2.6.9_67.0.22.EL_lustre.1.6.7smp_200903161648 \
    lustre:1.6.7-2.6.9_67.0.22.EL_lustre.1.6.7smp_200903161647 \
    lustre-modules:1.6.7-2.6.9_67.0.22.EL_lustre.1.6.7smp_200903161647 \
    neon:0.24.7-4 \
    subversion:1.1.4-2.ent \
    swig:1.3.21-6 \
    sge-execd:6.2-6.2u3-4 \
    screen:4.0.2-5 \
    gnuplot:4.0.0-4 \
    flex:2.5.4a-33 \
    perl-Error:0.17012-1.el4.rf \
    git-core:1.5.2.1-2.el4 \
    openmotif:2.2.3-10.1.el4 \
    tacc_outage:1.0-20 \
    tacc_outage2:2.0-3 \
    pam-sge:6.2u3-2 \
    firefox:1.5.0.7-0.1.el4.centos4 \
    ImageMagick:6.0.7.1-20.el4 \
    compute_ssh:1.0-1 \
    "

#    bash:3.2.48-1 \
#    tcsh:6.16-2 \
#    zsh:4.3.9-1 \
#    tacc_login_scripts-compute:2.0-19 \
#    tacc_login_scripts-login:2.0-16 \

#     tacc_login_scripts:2.0-5 \
#    login-scripts:1.3-27 \
#    tcsh:6.16-1 \
#    zsh:4.3.6-1 \
#    bash:3.0-19.6 \

gridftp_RPMS=" \
    tcsh:6.16-1 \
    zsh:4.3.6-1 \
    bash:3.0-19.6 \
    tacc_login_scripts-login:2.0-16 \
    login-scripts:1.3-27 \

    modules-base:3.1.6-15 \
    nxge:1.1-5 \
    lustre-ldiskfs:3.0.7.1-2.6.9_78.0.22.EL_lustre_TACC_200909211449 \
    lustre:1.6.7.2-2.6.9_78.0.22.EL_lustre_TACC_200909211439 \
    lustre-modules:1.6.7.2-2.6.9_78.0.22.EL_lustre_TACC_200909211439 \
    tacc_share_client:1.0-14 \
    tacc_work_client:1.0-11 \
    tacc_scratch_client:1.0-11 \
    tacc_corral:1.0-2 \
    sge-execd:6.1AR3-21 \
    zsh_tacc_test:4.3.9-1 \
    bash_tacc_test:3.2.48-1 \
    tcsh_tacc_test:6.16-2 \
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

gridftp_KERNEL_DATE="2.6.9-78.0.22.EL_lustre_TACC #2 SMP Mon Sep 21 15:12:44 CDT 2009"
gridftp_KERNEL="kernel-2.6.978.0.22.EL_lustre_TACC-1"

sge_KERNEL_DATE="2.6.9-67.0.22.EL_lustre.1.6.6smp #1 SMP Thu Sep 11 18:59:03 EDT 2008"
sge_KERNEL="kernel-lustre-smp-2.6.9-67.0.22.EL_lustre.1.6.6"

vis_KERNEL_DATE="2.6.9-67.0.22.EL_lustre.1.6.7smp #1 SMP Mon Mar 16 15:37:03 CDT 2009"
vis_KERNEL="kernel-2.6.967.0.22.EL_lustre.1.6.7smp-1"

master_KERNEL_DATE="2.6.9-78.0.22.EL_lustre_TACC #2 SMP Mon Sep 21 15:12:44 CDT 2009"
master_KERNEL="kernel-2.6.978.0.22.EL_lustre_TACC-1"

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







