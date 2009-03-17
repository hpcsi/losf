#!/bin/bash
#
#-------------------------------------------------------------
# Utility for installing previously downloading OS updates
# from CentOS mirror.
# 
# Originally: 4-15-2007 - ks
# Texas Advanced Computing Center
#-------------------------------------------------------------

# Inputs -------------------

export SRC_DIR=/share/home/0000/build/admin/os-updates/
export NODE_QUERY=/share/home/0000/build/admin/hpc_stack/node_types.sh
export DEBUG=1

# End Inputs -------------------

#---------------------
# Determine node type
#---------------------

. $NODE_QUERY > /dev/null

#---------------------------------
# Determine read location for rpms
#---------------------------------

export RPMDIR=$SRC_DIR$BASENAME/$PROD_DATE

if [ ! -d $RPMDIR ]; then
    echo "** Error: Unable to find up2date rpms for the current date!"
    echo "**        Be sure to run download_updates.sh first"
    echo "**"
    echo "**        Looking in $RPMDIR"
    echo " "
    exit 1
fi

#-------------------
# Already installed?
#-------------------

export NOT_UPDATED=0

if [ ! -e $RPMDIR/rpm_list ];then
    echo "** Error: unable to find $RPMDIR/rpm_list"
    echo "          please generate the list of rpms to verify first"
    exit 1
fi


for i in `cat $RPMDIR/rpm_list | tail -20`; do

    MYRPM=`echo $i | perl -pe 's/(.*).*.rpm/\1/g;'`
    DESIRED=`echo $i | perl -pe 's/(.*).(noarch|x86_64|i386|i686).rpm/\1/g;'`
#    DESIRED=`echo $myrpm |  perl -pe 's/(.*)\.[a-zA-Z0-9_]+$/\1/g;'`

    export RESULT=`rpm -q $MYRPM`

    if [ "$DESIRED" != "$RESULT" ];then
	if [ $DEBUG == 0 ];then 
	    echo "   --> desired rpm not installed $RESULT $i"
	fi
	NOT_UPDATED=1

	break
    fi
done

if [ $NOT_UPDATED == 0 ];then
    echo "$MYHOST is up to date with OS downloads...(quick check only)"
else
    echo "$MYHOST is **not** up2date with OS downloads...(quick check only)"
fi    



