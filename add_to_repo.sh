#!/bin/bash
#
#-------------------------------------------------------------
# Utility for adding updated OS rpms from CentOS mirror into
# the TACC Rocks Repo.
# 
# Note: node types for os-updates are defined in node_types.sh
#
# Usage add_to_repo.sh [add/remove]
# 
# Originally: 5-22-2007 - ks
# Texas Advanced Computing Center
#-------------------------------------------------------------

# Inputs ----------------------

export SRC_DIR=/share/home/0000/build/admin/os-updates/
export REPO_DIR=/export/home/install/contrib/4.2.1/
export MASTER_NODE=login3
export NODE_QUERY=/share/home/0000/build/admin/hpc_stack/node_types.sh
export INSTALL_DIR=/share/home/0000/build/admin/hpc_stack/

# End Inputs -------------------

MYARCH=`uname -p`

# Command-line parsing.

if [ $# -lt 1 ];then
	echo " "
	echo "Usage: $0 [add|remove]"
	echo " "
	exit 1
fi

if [ $1 == "add" ];then
    FLAG=1
elif [ $1 == "remove" ];then
    FLAG=0
else
    echo " "
    echo "Usage: $0 [add|remove]"
    echo " "
    exit 1
fi

echo " "
echo "---------------------------------"
echo "** TACC OS-Update Repo Updater **" 
echo "---------------------------------"

if [ `hostname -s` != $MASTER_NODE ];then
    echo " "
    echo "Error: this utility should be run from $MASTER_NODE"
    echo " "
    exit 1
fi

#---------------------
# Determine node type
#---------------------

. $NODE_QUERY

#-------------------------------
# Add/Remove the necessary rpms.
#-------------------------------

RPMS=`ls $SRC_DIR$BASENAME/$PROD_DATE/*.rpm` 
#echo $RPMS
#exit 1

if [ $FLAG == 1 ];then
    echo "--> Adding OS RPMS based on current production date:$PROD_DATE"
    echo "--> RPMs added to $REPO_DIR"
    for i in $RPMS; do
	echo "--> Adding $i to repo"
	cp $i $REPO_DIR/$MYARCH/RPMS
    done
elif [ $FLAG == 0 ];then
    echo "--> Removing OS RPMS based on current production date:$PROD_DATE"
    echo "--> RPMs removed from $REPO_DIR"
    for i in $RPMS; do
	myrpm=`echo $i | awk -F "$SRC_DIR$BASENAME/$PROD_DATE/" '{print $2}'`
	echo "--> Removing $myrpm from repo"
	echo "rm $REPO_DIR/$MYARCH/RPMS/$myrpm"
    done
fi










