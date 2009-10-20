#!/bin/bash
#
# $Id$
#
#-----------------------------------------------
# Function to verfy rpm installation 
# based on input rpm list provided by update.sh
# (also has a remove mode to make sure that a
# particular package is removed).
#
# Texas Advanced Computing Center 
#-----------------------------------------------

function verify_rpms
{

    local RPM_LIST=$1 
    local REMOVE_FLAG=$2

    if [ "$REMOVE_FLAG" != "REMOVE" ];then

    for i in $RPM_LIST; do
	let "count = count + 1"
	
	export PACKAGE=`echo $i | awk -F : '{print $1}'`
	export VERSION=`echo $i | awk -F : '{print $2}'`
###	export INSTALLED=`rpm -q $PACKAGE-$VERSION | awk -F "$PACKAGE-" '{print $2}'`
	export INSTALLED=`rpm -q $PACKAGE-$VERSION | awk -F "$PACKAGE-" '{print $2}'`
	export NOT_INSTALLED=`echo $INSTALLED | awk '{print $3}'`

	if [ "$VERSION" != "$INSTALLED" ];then
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

		if [ -s $SRC_DIR/$MYARCH/$PACKAGE-$VERSION.$MYARCH.rpm ]; then
		    rpm --ignoresize -Uvh --nodeps $SRC_DIR/$MYARCH/$PACKAGE-$VERSION.$MYARCH.rpm
		elif [ -s $SRC_DIR/noarch/$PACKAGE-$VERSION.noarch.rpm ]; then
		    rpm --ignoresize -Uvh --nodeps $SRC_DIR/noarch/$PACKAGE-$VERSION.noarch.rpm
		elif [ "$MODE" == "ROCKS" ];then
		    rpm --ignoresize -Uvh --nodeps $SRC_DIR/$MYARCH/$PACKAGE-$VERSION.$MYARCH.rpm
		else
		    echo "$SRC_DIR/$MYARCH"
		    echo "Error: Unable to find rpm for $PACKAGE"
		    exit 1
		fi

		# Special Post-processing for kernel installs.

		if [ "$PACKAGE" = "kernel" ]; then
		    echo "Updating kernel initrd image."
		    export KERNEL_VER=`echo $VERSION | awk -F "-" '{print $1}'`
		    echo "Image name = $KERNEL_VER.img"
		    /sbin/mkinitrd -f /boot/initrd-$KERNEL_VER.img --preload=mptsas --preload=mptscsih $KERNEL_VER
		fi
	    fi
	else
	    if [ "$VERBOSE" == 1 ]; then
		printf "%-25s %8s" $PACKAGE $INSTALLED
		printf "%8s\n" "X"
	    fi
	fi
    done

    else

	# Verify non-existence of RPMs

	for i in $RPM_LIST; do

	    let "count = count + 1"
	
	    export PACKAGE=`echo $i | awk -F : '{print $1}'`
	    export VERSION=`echo $i | awk -F : '{print $2}'`
	    export INSTALLED=`rpm -q $PACKAGE-$VERSION | awk -F "$PACKAGE-" '{print $2}'`

	    if [ "$VERSION" == "$INSTALLED" ];then
		echo "$PACKAGE is *installed* and will be removed"
		export NEEDS_UPDATE=1
		
            # Uninstall the desired package.
		
		if [ $UPDATE_RPMS == 1 ];then
#		    echo "rpm -e --ignoresize --nodeps $i"
		    rpm -e --ignoresize --nodeps $PACKAGE-$VERSION
		fi
	    fi
	    
	done

    fi
	
}
