#!/bin/bash

# Inputs -------------------

export VERBOSE=0
export UPDATE_RPMS=1

# End Inputs -------------------

export COUNT=0
export NEEDS_UPDATE=0
export MYHOST=`hostname -s`

export SRC_DIR="/home/build/rpms/RPMS/x86_64"
#export SRC_DIR="/home/build/rpms/RPMS/ /home/build/admin/os-updates/3.13.07/rpms_only"
export UP2DATE_DIR=~build/admin/os-updates/3.13.07/rpms_only
export MYARCH=x86_64

#------------------
# Login Only RPMS
#------------------

echo "TACC: Building rpm list to verify..."

# These first ones are only on lslogin1 since they are 
# in a shared /data/apps

#LOGIN_RPMS="ddt:1.10-4 \
#    R:2.4.1.full-1 \

LOGIN_RPMS="
    atlogin:1.0-2 \
    amgr:2.0-1 \
    apr:util-0.9.4-21 \
    guile:1.6.4-14 \
    neon:0.24.7-4 \
    amber9-devel:9-4 \
    swig:1.3.21-6 \
    sysfsutils-devel:1.2.0-1 \
    lustre:1.4.9-2.6.9.42.0.10.EL_Lustre_200703132000 \
    lustre-modules:1.4.9-2.6.9.42.0.10.EL_Lustre_200703132000"


#for package in `ls $UP2DATE_DIR/*.rpm` ; do
#    export pname=`rpm -qip $package | grep "^Name" | awk '{print $3}'`
#    export pversion=`rpm -qip $package | grep "^Version" | awk '{print $3}'`
#    export prelease=`rpm -qip $package | grep "^Release" | awk '{print $3}'`
#    LOGIN_RPMS="$pname:$pversion-$prelease $LOGIN_RPMS"
#done

echo "TACC: Login RPM list complete".

for package in $LOGIN_RPMS ; do
    echo "Tracking versions of $package"
done

LOGIN_NODES="lslogin1 lslogin2 c0-501 osg-login"

if [ "$VERBOSE" == 1 ]; then
    echo "------------------------------------------------"
    echo "Package                   Version    Up-to-Date?"
    echo "------------------------------------------------"
fi

#-----------
# Functions
#-----------

function verify_rpms
{
    local RPM_LIST=$1 

    for i in $RPM_LIST; do
	let "count = count + 1"
	
	export PACKAGE=`echo $i | awk -F : '{print $1}'`
	export VERSION=`echo $i | awk -F : '{print $2}'`
# yes this is a hack
#	export INSTALLED=`rpm -q $PACKAGE-$VERSION | head -1 | awk -F "$PACKAGE-" '{print $2}'`
	export INSTALLED=`rpm -q $PACKAGE-$VERSION | awk -F "$PACKAGE-" '{print $2}'`
	export NOT_INSTALLED=`echo $INSTALLED | awk '{print $3}'`

	if [ "$VERSION" != "$INSTALLED" ];then
	    echo "$VERSION $INSTALLED"
	    echo "checking on $PACKAGE"
	    export NEEDS_UPDATE=1

	    if [ "$VERBOSE" == 1 ]; then
		printf "%-25s %8s" $PACKAGE $INSTALLED
		printf "%8s\n" "No"
	    else
		if [ "$NOT_INSTALLED" == "not" ]; then
		    echo "$PACKAGE is *not* Installed, Desired = $VERSION"
		else
		    echo "$PACKAGE is out of date: Installed = $INSTALLED, Desired = $VERSION"
		fi
	    fi
	    
            # Install the desired package.
		
	    if [ $UPDATE_RPMS == 1 ];then

		export mydir=""

		for dir in $SRC_DIR; do 

		    if [ -s $dir/$MYARCH/$PACKAGE-$VERSION.$MYARCH.rpm ]; then
			export mydir=$dir/$MYARCH
		    elif [ -s $dir/noarch/$PACKAGE-$VERSION.noarch.rpm ]; then
			export mydir=$dir/noarch
		    elif [ -s $dir/$PACKAGE-$VERSION.$MYARCH.rpm ]; then
			export mydir=$dir
		    elif [ -e $dir/$PACKAGE-$VERSION.noarch.rpm ]; then
			export mydir=$dir
		    elif [ -e $dir/$PACKAGE-$VERSION.i386.rpm ]; then
			export mydir=$dir
		    fi

		done

		if [ "x$mydir" == "x" ];then
		    echo "Error: Unable to find rpm for $PACKAGE ($dir)"
		    exit 1
		fi

		if [ -s $dir/$PACKAGE-$VERSION.$MYARCH.rpm ]; then
		    echo "found $dir/$PACKAGE-$VERSION.$MYARCH.rpm"
		    rpm --ignoresize --nodeps -Uvh $dir/$PACKAGE-$VERSION.$MYARCH.rpm
		elif [ -s $dir/$PACKAGE-$VERSION.noarch.rpm ]; then
		    rpm --ignoresize --nodeps -Uvh $dir/$PACKAGE-$VERSION.noarch.rpm
		fi

		if [ -s $dir/$PACKAGE-$VERSION.i386.rpm ]; then
		    rpm --ignoresize --nodeps -Uvh $dir/$PACKAGE-$VERSION.i386.rpm
		fi

	    fi
	else
	    if [ "$VERBOSE" == 1 ]; then
		printf "%-25s %8s" $PACKAGE $INSTALLED
		printf "%8s\n" "X"
	    fi
	fi
    done
}

#----------------------------------------------
# Install software common to login nodes only.
#----------------------------------------------

IS_A_LOGIN_NODE=0

for j in $LOGIN_NODES; do
    if [ $j == $MYHOST ]; then
	echo " "
	echo "This is a login node, ignoring compute-only rpms..."
	IS_A_LOGIN_NODE=1 
	break
    fi
done

if [ $IS_A_LOGIN_NODE == 1 ];then
    echo " "
    echo "Validating login-only software"
    echo " "
    verify_rpms "$LOGIN_RPMS"
fi


if [ "$NEEDS_UPDATE" == 1 ]; then
    echo " "
    echo "** $MYHOST needs updating"
else
    echo "$MYHOST is up to date with $count packages"
fi




