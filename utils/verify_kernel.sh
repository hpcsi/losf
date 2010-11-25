#!/bin/bash
#
# $Id$
#
#-----------------------------------------------
# Function to verfy kernel installation
# based on input rpm list provided by update.sh
#
# Texas Advanced Computing Center 
#-----------------------------------------------

export ROCKS_DIR=/home/build/rpms/RPMS/x86_64/
#export GRUB_DIR=/home/build/kernel/grub_entries

function verify_kernel
{
    local KERNEL_REV=$1 
    local KERNEL_RPM=$2
    local GRUB_DIR=$3

    if [ "$KERNEL_REV" == "current" -o "$KERNEL_RPM" == "current" ];then
	return
    fi

    myvalue=`uname -rv`

    if [ "$myvalue" != "$KERNEL_REV" ];then
	echo "kernel is out of date: "
	echo "  --> Running = $myvalue"
	echo "  --> Desired = $KERNEL_REV"
	export NEEDS_UPDATE=1

	# Check if it is installed but not running.

	export INSTALLED=`rpm -q $KERNEL_RPM` 
	if [ "$INSTALLED" == "$KERNEL_RPM" ];then
	    echo "  --> Kernel rpm is installed; please verify grub.conf and reboot"
	else
	    revision=`echo $KERNEL_REV | awk '{print $1}'`
###	    rpm -ivh --nodeps --ignoresize $ROCKS_DIR/$KERNEL_RPM.$MYARCH.rpm
	    rpm -Uvh --nodeps --ignoresize $ROCKS_DIR/$KERNEL_RPM.$MYARCH.rpm
	    mkinitrd -f /boot/initrd-$revision.img $revision
	    depmod -a

	    echo " "
	    echo "Using production grub.conf file from the following location:"
	    echo "--> $GRUB_DIR"

	    cp $GRUB_DIR/grub.conf /boot/grub/grub.conf
	    echo "--> Make sure to verify grub.conf and reboot."

	fi
    else
	# Check for running, but not installed

	export INSTALLED=`rpm -q $KERNEL_RPM` 
	if [ "$INSTALLED" != "$KERNEL_RPM" ];then
	    echo "Kernel is running, but no longer installed"

	    revision=`echo $KERNEL_REV | awk '{print $1}'`
	    rpm -ivh --nodeps --ignoresize $ROCKS_DIR/$KERNEL_RPM.$MYARCH.rpm
	    mkinitrd -f /boot/initrd-$revision.img $revision

	    echo " "
	    echo "Using production grub.conf file from the following location:"
	    echo "--> $GRUB_DIR"

	    cp $GRUB_DIR/grub.conf /boot/grub/grub.conf
	    echo "--> Make sure to verify grub.conf and reboot."
	fi
    fi

}

