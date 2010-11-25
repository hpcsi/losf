# -*-sh-*-
#!/bin/bash
#----------------------------------------------------------------------
# LosF Software Updates
# 
# Utility to update individual cluster node types to
# latest production revision (or verify that a node is already
# in sync).
#
# $Id$
#----------------------------------------------------------------------
#
# Node definitions are controlled via the LosF input files located in the
# top-level config/ directory.  To customize your cluster, you will
# want to create an update.<your-cluster-name> file to define desired
# RPM packages for each of your node definitions.  A template file is
# provided in update.template.
#
# Ranger Version:   Originally 6/21/07 - ks 
# Longhorn Version:   10-25-09
# Lonestar42 Updates: 11-24-10
#
# Questions/Problems?: karl@tacc.utexas.edu
# Texas Advanced Computing Center 
#----------------------------------------------------------------------
#----------------------------------------------------------------------

# Command-line Inputs

# Inputs -------------------

export VERBOSE=0
export UPDATE_RPMS=1

# End Inputs -------------------

export MYHOST=`hostname -s`
export RPM_DIR=/home/build/rpms/RPMS/
export REMOTE_INSTALL_DIR=/home/build/admin/hpc_stack/

#-------------------------------------
# Command-Line Options 
# Used to setup rpm install location
# for use with PXE initiated installs
#-------------------------------------

NUM_ARGS=$#
if [ $# -gt 1 -a "$1" = "PXE" ];then
    export SRC_DIR=$2
    export INSTALL_DIR=/home/build/admin/hpc_stack
    export MODE="ROCKS"

    echo " "
    echo "** Running update.sh in PXE install mode"
    echo "** -> Installing from $SRC_DIR"
else
    export SRC_DIR=$RPM_DIR
    export INSTALL_DIR=$REMOTE_INSTALL_DIR
    export MODE="INTERACTIVE"
fi

#-------------------
# Query type of node
#-------------------

export TOP_DIR=`echo $( (cd -P $(dirname $0) && pwd) )`

export NODE_TYPE_SILENT=1

RESULT=`$TOP_DIR/node_types | grep Node_Type | awk '{print $3}'`
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
    if [ -x $TOP_DIR/update.$CLUSTER ];then
	echo " "
	echo "Performing Updates for $CLUSTER -> $BASENAME node type"
	echo " "
    else
	echo " "
	echo "[Error]: Unable to perform updates"
	echo "[Error]: $TOP_DIR/update.$CLUSTER is not present or executable"
	echo " "
	echo "Please create necessary file to perform desired software updates."
	echo " "
	exit 1
    fi
fi









