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
export INSTALL_DIR=/share/home/0000/build/admin/hpc_stack/
export NODE_QUERY=/share/home/0000/build/admin/hpc_stack/node_types.sh
export DEBUG=1

# End Inputs -------------------

echo " "
echo "---------------------------------"
echo "** TACC OS-Update Installation **" 
echo "---------------------------------"

#---------------------
# Determine node type
#---------------------

. $NODE_QUERY

#---------------------------------
# Determine read location for rpms
#---------------------------------

#export DATE=`date +%F`
mkdir -p $SRC_DIR/$BASENAME/$PROD_DATE
export RPMDIR=$SRC_DIR$BASENAME/$PROD_DATE

if [ ! -d $RPMDIR ]; then
    echo "** Error: Unable to find up2date rpms for the current date!"
    echo "**        Be sure to run download_updates.sh first"
    echo "**"
    echo "**        Looking in $RPMDIR"
    echo " "
    exit 1
fi

echo "Installing downloaded up2date rpms from $RPMDIR..."

#-------------------
# Already installed?
#-------------------

echo "Checking if desired rpms are already installed..."

export NOT_UPDATED=0
export MISSING_RPMS=""

for i in $RPMDIR/*.rpm; do
    export RESULT=`rpm -U --test $i 2>&1 | grep "already installed"`

###    echo $RESULT

    if [ "x$RESULT" == "x" ];then

	if [ $DEBUG == 0 ];then 
	    echo "   --> desired rpm not installed $RESULT $i"
	fi
	MISSING_RPMS="$MISSING_RPMS $i"
	NOT_UPDATED=1
###	break
    fi
done

if [ $NOT_UPDATED == 0 ];then
    echo "** $MYHOST is up2date with OS downloads..."
    exit 0
fi
    
#------------------
# Verify the rpms
#------------------

echo "Verifying rpm dependencies..."

export VERIFY=`rpm -U --ignoresize --test $RPMDIR/*.rpm 2>&1`
PARTIAL_INSTALL=`echo $VERIFY | grep -v "is already installed"` 
export RPM_EXTRA_OPTION=""
export INCREMENTAL=0

if [ "x$VERIFY" == "x" ];then
    echo "Dependencies verified; proceeding with installation..."
    echo " "
elif [ "x$PARTIAL_INSTALL" == "x" ];then
    echo " "
    echo "Note: Partial install detected; it looks like a previous attempt"
    echo "to install package updates was only partially successful."
    echo " "
    echo "Picking up from previous install...."
    export INCREMENTAL=1
    export RPM_EXTRA_OPTION="--replacepkgs"
else
    echo " "
    echo "** Error: rpm dependencies not verified; this may mean that the"
    echo "**        host node which downloaded the os updates differs from the"
    echo "**        current installation target"
    echo " "
    echo "$VERIFY"
    echo "partial = $PARTIAL_INSTALL"
    exit 1
fi

###exit 0

#---------------------
# Install the packages
#---------------------

# if [ $INCREMENTAL ];then
#     echo "rpm -Uvh --ignoresize $RPM_EXTRA_OPTION $MISSING_RPMS"
# else
#     echo "rpm -Uvh --ignoresize $RPM_EXTRA_OPTION $RPMDIR/*.rpm"
# fi

rpm -Uvh --ignoresize $RPM_EXTRA_OPTION $RPMDIR/*.rpm

exit 1

cd $RPMDIR

for i in `ls *.rpm`; do
#    echo $i

    pkg=`echo $i | perl -pe 's/(\S+).(noarch|x86_64|i386).rpm/$1/'`

#    pkg=`echo $i | awk -F '.x86_64.rpm' '{print $1}'`

#     if [ x"$pkg" == "x" ];then
# 	echo "checking for noarch"
# 	pkg=`echo $i | awk -F '.noarch.rpm' '{print $1}'`
#     fi

#     if [ x"$pkg" == "x" ];then
# 	echo "checking for i386"
# 	pkg=`echo $i | awk -F '.i386.rpm' '{print $1}'`
#     fi
	
    igot=`rpm -q $pkg`

    if [ "$igot" != "$pkg" ];then
	echo "** Installing $pkg...."
	rpm -Uvh --nodeps  --ignoresize ./$i
    fi

done

###rpm -Uvh --ignoresize $RPM_EXTRA_OPTION $RPMDIR/*.rpm
#rpm "$ROLLBACK_MACRO" --ignoresize -Uvh $RPM_EXTRA_OPTION $ROLLBACK_OPTS $RPMDIR/*.rpm



