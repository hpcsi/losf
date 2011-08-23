#!/bin/bash
#
# $Id$
#
#-----------------------------------------------------------------------
# Designation of cluster node types and software production dates for
# any general OS revisions.

# Typical node types for an HPC cluster are:
#
# master, login, Lustre oss/mds, and compute.
# 
# Syntax for the designation is "node_type:hostname". For convenience, 
# the hostname designation can be replaced by a regular expression.
#
# Originally: 04-15-2007 -> Lonestar3 version
#             06-21-2007 -> Ranger    version
#             10-19-2009 -> Longhorn2 version (with more generality)
#
# Questions/Problems?: karl@tacc.utexas.edu
# Texas Advanced Computing Center 
#-----------------------------------------------------------------------

export PRODUCTION_DATE_login="2009-10-19"
export PRODUCTION_DATE_master="2007-12-01"
export PRODUCTION_DATE_oss="2007-06-21"
export PRODUCTION_DATE_mds="2007-06-21"
export PRODUCTION_DATE_sge="2007-06-21"
export PRODUCTION_DATE_compute="2009-01-16" 

NODE_TYPES=( login:"login[1-2]" oss:"oss[1-9]+" mds:mds[1-6] \
             compute:"\bcompute-*-*|\bc-*-*|\bamd|\bi-*-*|build|localhost" \
             master:"master.longhorn" )

# End Inputs -------------------

export MYHOST=`hostname -s`

#---------------------
# Determine node type
#---------------------

COMPUTE_NODE=0
export BASENAME="undefined"

num_appliances="${#NODE_TYPES[@]}"

if [ "$NODE_TYPE_SILENT" == "" ];then
    NODE_TYPE_SILENT=0
fi

for j in ${NODE_TYPES[@]}; do

    test_type=`echo $j | awk -F: '{print $1}'`
    test_host=`echo $j | awk -F: '{print $2}'`

    result=`echo $MYHOST | egrep $test_host`

    if [ "$result" == "$MYHOST" ]; then

	if [ $NODE_TYPE_SILENT != 1 ];then
	    echo " "
	    echo "This is a $test_type node...($MYHOST)"
	fi

	export BASENAME=$test_type
	
	if [ ${test_type} == "login" ];then
	    PROD_DATE=$PRODUCTION_DATE_login
	elif [ "$test_type" == "gridftp" ];then
	    PROD_DATE=$PRODUCTION_DATE_gridftp
	elif [ "$test_type" == "master" ];then
	    PROD_DATE=$PRODUCTION_DATE_master
	elif [ "$test_type" == "mds" ];then
	    PROD_DATE=$PRODUCTION_DATE_mds
	elif [ "$test_type" == "oss" ];then
	    PROD_DATE=$PRODUCTION_DATE_oss
	elif [ "$test_type" == "sge" ];then
	    PROD_DATE=$PRODUCTION_DATE_sge
	elif [ "$test_type" == "vis" ];then
	    PROD_DATE=$PRODUCTION_DATE_vis
 	elif [ "$test_type" == "compute" ];then
	    PROD_DATE=$PRODUCTION_DATE_compute
	    COMPUTE_NODE=1
	fi
    fi

done

if [ "$BASENAME" == "undefined" ];then
    echo " "
    echo "[Error]: Unable to determine the node type for this host ($MYHOST)."
    echo "[Error]: Is this host and cluster defined in the global LosF config/config.machines file?"
    echo " "
    exit 1
fi

if [ $NODE_TYPE_SILENT != 1 ];then
    echo "--> os-update production date = $PROD_DATE"
    echo "basename = $BASENAME"

    if [ COMPUTE_NODE == 1 ];then
	echo " "
    	echo "This is a compute node...($MYHOST)"
	export BASENAME=compute
	export PROD_DATE=$PRODUCTION_DATE_compute
	echo "--> os-update production date = $PROD_DATE"
	echo " "
    fi
fi


