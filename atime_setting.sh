#!/bin/bash
# 
# Verify atime setting.

# Disable ip forwarding...

igot=`cat /etc/fstab | grep "LABEL=/"  | grep noatime | wc -l`
if [ "$igot" != "1" ];then
    echo "--> FAILED: noatime for CF is not enabled"
    perl -pi -e 's/(ext2\s+)(defaults)/$1defaults,noatime/' /etc/fstab
    echo "-->Remounting / file system"
    mount -o remount /
    igot=`mount | grep ext2 | wc -l`
    if [ "$igot" == "1" ];then
	echo "--> Remount successful"
    else
	echo "--> Error: remount unsuccessful"
    fi
else
    echo "--> Passed: noatime for CF is enabled"
fi

