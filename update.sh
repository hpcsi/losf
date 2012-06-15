# -*-sh-*-
#!/bin/bash
#----------------------------------------------------------------------
# LosF Software Updates
# 
# Utility to update individual cluster node types to latest production
# revision (or verify that a node is already in sync).
#
# $Id$
#----------------------------------------------------------------------
#
#
# Node type definitions are controlled via the LosF input files
# located in the top-level config/ directory.  To customize your
# cluster, you will want to create an update.<your-cluster-name> file
# to define desired RPM packages for each of your node definitions.  A
# template file is provided in update.template.
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

export TOP_DIR=`echo $( (cd -P $(dirname $0) && pwd) )`
export PERL5LIB=$TOP_DIR/utils
export MYHOST=`hostname -s`

#----------------------------------------------------------------
# Perform LosF updates (todo, handle PXE arguments appropriately)
#----------------------------------------------------------------

$TOP_DIR/utils/update.pl 

#-------------------
# Query node type
#-------------------

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
	echo "Running update.$CLUSTER to perform local customizations for $CLUSTER -> $BASENAME node type"
	echo " "

	$TOP_DIR/update.$CLUSTER $@
    fi
###    else
###	echo " "
###	echo "[Warning]: Unable to perform updates"
###	echo "[Warning]: $TOP_DIR/update.$CLUSTER is not present or executable"
###	echo " "
###	echo "Please create necessary file to perform desired software updates."
###	echo " "
###	exit 1
###    fi
fi









