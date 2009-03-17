#!/bin/bash
# 
# Verify various networking settings for a Ranger compute blade.

MASTER="192.168.0.1"
ARP_THRESH3="16392"
ARP_THRESH2="8196"
ARP_THRESH1="4098"

# Set to 1 on the command line for pass/fail 
# mode; default is to be verbose.

if [ $# -gt 1 ];then
    MODE=$1			
else	
    MODE=0
fi

myhost=`hostname -s`

if [ $MODE -ne 1 ];then

    echo " "
    echo "----------------------------------------"
    echo "Verifying Network Settings on $myhost"
    echo "----------------------------------------"
    
fi

# Disable ip forwarding...

igot=`grep "net.ipv4.ip_forward" /etc/sysctl.conf | awk '{print $3}'`
if [ "$igot" == "1" ];then
    if [ $MODE -ne 1 ];then
	echo "--> FAILED: ipv4 forwarding is enabled"
    fi
    perl -pi -e 's/net.ipv4.ip_forward = 1/net.ipv4.ip_forward=0/' /etc/sysctl.conf
    sysctl -p
    sysctl -a | grep ipv4.ip_forward
else
    if [ $MODE -ne 1 ];then
	echo "--> Passed: ipv4 forwarding is disabled"
    fi
fi

# Verify 411 configuration...

igot=`grep "master url" /etc/411.conf | awk -F / '{print $3}'`

if [ "$igot" != "$MASTER" ];then
    echo "--> FAILED: 411 master host is wrong"
    eval perl -pi -e 's/$igot/$MASTER/' /etc/411.conf
    /etc/init.d/greceptor restart
else
    echo "--> Passed: 411 master host is correct"
fi

# Verify resolv.conf...

igot=`grep nameserver /etc/resolv.conf | awk '{print $2}'`

if [ "$igot" != "$MASTER" ];then
    echo "--> FAILED: nameserver host is wrong"
    eval "perl -pi -e 's/$igot/$MASTER/' /etc/resolv.conf"
else
    echo "--> Passed: nameserver host is correct"
fi

# Verify gateway...

igot=`grep GATEWAY /etc/sysconfig/network | awk -F = '{print $2}'`

if [ "$igot" != "$MASTER" ];then
    echo "--> FAILED: gateway host is wrong ($igot)"
    eval perl -pi -e 's/$igot/$MASTER/' /etc/sysconfig/network
else
    echo "--> Passed: gateway host is correct"
fi

# Verify ARP thresholds

igot=`sysctl net.ipv4.neigh.default.gc_thresh3 | awk '{print $3}'`

if [ "$igot" !=  "$ARP_THRESH3" ];then
    echo "--> FAILED: ipv4.gc_thresh3 is wrong"
    sysctl -q -w  net.ipv4.neigh.default.gc_thresh3=$ARP_THRESH3
else
    echo "--> Passed: ipv4.gc_thresh3 is correct ($igot)"
fi

igot=`sysctl net.ipv4.neigh.default.gc_thresh2 | awk '{print $3}'`

if [ "$igot" !=  "$ARP_THRESH2" ];then
    echo "--> FAILED: ipv4.gc_thresh2 is wrong"
    sysctl -q -w  net.ipv4.neigh.default.gc_thresh2=$ARP_THRESH2
else
    echo "--> Passed: ipv4.gc_thresh2 is correct ($igot)"
fi

igot=`sysctl net.ipv4.neigh.default.gc_thresh1 | awk '{print $3}'`

if [ "$igot" !=  "$ARP_THRESH1" ];then
    echo "--> FAILED: ipv4.gc_thresh1 is wrong"
    sysctl -q -w  net.ipv4.neigh.default.gc_thresh1=$ARP_THRESH1
else
    echo "--> Passed: ipv4.gc_thresh1 is correct ($igot)"
fi

# Verify temporary fstab entry

igot=`grep "/export" /etc/fstab | awk -F : '{print $1}'`

if [ "$igot" !=  "$MASTER" ];then
    echo "--> FAILED: temporary fstab entry for /export is wrong"
    eval perl -pi -e 's/$igot/$MASTER/' /etc/fstab
else
    echo "--> Passed: temporary fstab entry for /export is correct"
fi

# Verify ntp setting

igot=`grep server /etc/ntp.conf  | awk '{print $2}'`

if [ "$igot" !=  "$MASTER" ];then
    echo "--> FAILED: ntp server host is incorrect"
    eval perl -pi -e 's/$igot/$MASTER/' /etc/ntp.conf
    /etc/init.d/ntp restart
else
    echo "--> Passed: ntp server host is correct"
fi

# Verify postfix setting

igot=`grep "relayhost = 1" /etc/postfix/main.cf  | awk '{print $3}'`

if [ "$igot" !=  "$MASTER" ];then
    echo "--> FAILED: postfix relay host is incorrect"
    eval "perl -pi -e 's/"$igot"/"$MASTER"/' /etc/postfix/main.cf"
    /etc/init.d/postfix restart
else
    echo "--> Passed: postfix relay host is correct"
fi

# Verify syslog setting

igot=`grep "\*.\*" /etc/syslog.conf  | awk -F "@" '{print $2}'`

if [ "$igot" !=  "$MASTER" ];then
    echo "--> FAILED: syslog host is incorrect"
    eval "perl -pi -e 's/"$igot"/"$MASTER"/' /etc/syslog.conf"
    /etc/init.d/syslog restart
else
    echo "--> Passed: syslog relay host is correct"
fi

# Verify IPoIB arp settings

# igot2=`ifconfig | grep ib0 | awk '{print $1}'`
# if [ "$igot2" != "ib0" ];then
#     echo "**> Warning: Unable to verify ib0 arp settings; interface is down."
# else

#     igot=`sysctl net.ipv4.conf.ib0.arp_ignore | awk '{print $3}'`

#     if [ "$igot" !=  "1" ];then
# 	echo "--> FAILED: ipv4.conf.ib0.arp_ignore is wrong"
# 	sysctl -q -w  net.ipv4.conf.ib0.arp_ignore=1 
#     else
# 	echo "--> Passed: ipv4.conf.ib0.arp_ignore is correct ($igot)"
#     fi
# fi

# Verify IPoIB arp settings

# igot2=`ifconfig | grep ib2 | awk '{print $1}'`
# if [ "$igot2" != "ib2" ];then
#     echo "**> Warning: Unable to verify ib2 arp settings; interface is down."
# else

#     igot=`sysctl net.ipv4.conf.ib2.arp_ignore | awk '{print $3}'`

#     if [ "$igot" !=  "1" ];then
# 	echo "--> FAILED: ipv4.conf.ib2.arp_ignore is wrong"
# 	sysctl -q -w  net.ipv4.conf.ib2.arp_ignore=1 
#     else
# 	echo "--> Passed: ipv4.conf.ib2.arp_ignore is correct ($igot)"
#     fi
# fi





