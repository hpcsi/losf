#!/bin/bash
#
# $Id: verify_rack.sh,v 1.3 2007/12/17 12:17:31 karl Exp $
#
#-----------------------------------------------
# Function to verfy TACC software stack and
# IB Settings on a Ranger Rack
#
# Originally: 12-1-2007 - ks
# Texas Advanced Computing Center 
#-----------------------------------------------

SRC_DIR=~build/admin/hpc_stack/
SRC_DIR=/share/home/0000/build/admin/hpc_stack/

if [ $# -lt 1 ];then
    echo "Usage: verify_rack <rack-number>"
    exit 1
fi

rack=$1

#~/koomie_cf.pl -r $rack 'if [ `mount | grep -c export` == 0 ]; then mount /export; fi;'

#--------------------
# 1st: Check IB_Mode
#--------------------

TMPFILE=/tmp/.verify_rack_ib.$RANDOM

~/koomie_cf.pl -m 200 -r $rack $SRC_DIR/ib_mode.sh 1 | grep -v "Passed" >& $TMPFILE

igot=`cat $TMPFILE`

#if [ -z $igot ];then
if [ "$igot" == "" ];then
    echo "Rack(s) $rack -> IB_Mode PASSED"
else
    echo "Rack(s) $rack -> IB_Mode FAILED"
    echo "$igot"
fi

if [ -e $TMPFILE ];then
    rm -f $TMPFILE
fi

#----------------------
# 2nd: Check S/W Stack
#----------------------

TMPFILE=/tmp/.verify_rack_sw.$RANDOM

~/koomie_cf.pl -t 600 -m 200 -r $rack $SRC_DIR/update.sh  | grep -v "is up to date" >& $TMPFILE

igot=`cat $TMPFILE`

if [ -z "$igot" ];then
    echo "Rack(s) $rack -> SW Stack PASSED"
else
    echo "Rack(s) $rack -> SW Stack FAILED"
    echo "$igot"
fi

if [ -e $TMPFILE ];then
    rm -f $TMPFILE
fi

# Third Temporary Check

#echo "...Temporarily verifying number of valid responses..."

igot=`~/koomie_cf.pl -m 200 -r $rack hostname | grep ranger.tacc.utexas.edu | wc -l`

echo "Number of successful returns = $igot"
