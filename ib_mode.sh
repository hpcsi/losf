!/bin/bash
# 
# $Id: ib_mode.sh,v 1.19 2008/10/04 19:21:14 karl Exp $
#
#--------------------------------------------------------------
# Enforce/verify IPoIB settings for a Ranger compute blade.
#
# Texas Advanced Computing Center
# The University of Texas at Austin
#--------------------------------------------------------------

MASTER="129.114.96.1"
GATEWAY="129.114.96.9"
ARP_THRESH3="16392"
ARP_THRESH2="8196"
ARP_THRESH1="4098"

# IPs for DNS round robin (based solely on racks numbers)

DNS1=129.114.96.6
DNS2=129.114.96.7
DNS3=129.114.96.8
DNS4=129.114.96.9

myhost=`hostname | awk -F . '{print $1}'`
result=`echo $myhost | egrep "\bc-*-*|\bi-*-*"`
compute_mode=0

if [ "$result" == "$myhost" ];then
    compute_mode=1
fi

IGNORE_RESTART=0
#NET_DIR=~build/admin/hpc_stack/networking/IPoIB/
NET_DIR=/share/home/0000/build/admin/hpc_stack/networking/IPoIB/

if [ $# -ge 1 ];then
    if [ "$1" == ROCKS ];then
	IGNORE_RESTART=1
	NET_DIR=/tacc/tacc-sw-update/networking/IPoIB/
	
	myhost=`cat /etc/sysconfig/network | grep HOSTNAME | cut -d = -f 2 | awk -F . '{print $1}'`

	# We want IPoIB to start with "i" as opposed to "c"
	
	igot=`echo $myhost | cut -c 2-8`
	myhost="i$igot"
    fi
fi		

# Do we want to verify ib2 interface?
COM_MASK="c...-...|i...-..."		
result=`echo $myhost | egrep $COM_MASK`

if [ "$myhost" == "$result" ];then
    CHECK_IB2=0
else
    CHECK_IB2=1
fi

# Set to 1 on the command line for pass/fail 
# mode; default is to be verbose.

if [ $# -ge 1 ];then
    MODE=$1			
else	
    MODE=0
fi

if [ $MODE -ne 1 ];then

    echo " "
    echo "--------------------------------------------------"
    echo "Verifying IPoIB Mode Network Settings on $myhost"
    echo "--------------------------------------------------"
    
fi

#-------------------------
# Disable ip forwarding...
#-------------------------

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

#----------------------------
# Verify 411 configuration...
#----------------------------

igot=`grep "master url" /etc/411.conf | awk -F / '{print $3}'`

if [ "$igot" != "$MASTER" ];then
    echo "--> FAILED: 411 master host is wrong"
    eval perl -pi -e 's/$igot/$MASTER/' /etc/411.conf
    if [ $IGNORE_RESTART -ne 1 ];then
	/etc/init.d/greceptor stop
    fi
else
    echo "--> Passed: 411 master host is correct"
fi

#-------------------------------------
# Verify resolv.conf...
# Updated to handle dns round-robin
#-------------------------------------

igot=`grep nameserver /etc/resolv.conf | head -1 | awk '{print $2}'`

if [ $compute_mode -eq 1 ];then
    RACK=`echo $myhost | awk -F - '{print $1}'`
    RACKNUM=`echo $RACK | awk -F i '{print $2}'`
    rio=`expr $RACKNUM % 4`
else
    rio=1
fi

if [ "$rio" == "1" ];then
    NS1=$DNS1
    NS2=$DNS2
    NS3=$DNS3
    NS4=$DNS4
elif [ "$rio" == "2" ];then
    NS1=$DNS2
    NS2=$DNS3
    NS3=$DNS4
    NS4=$DNS1
elif [ "$rio" == "3" ];then
    NS1=$DNS3
    NS2=$DNS4
    NS3=$DNS1
    NS4=$DNS2
elif [ "$rio" == "0" ];then
    NS1=$DNS4
    NS2=$DNS1
    NS3=$DNS2
    NS4=$DNS3
fi

if [ "$igot" != "$NS1" ];then
    echo "--> FAILED: First round-robin nameserver host is wrong"
    echo "nameserver $NS1" >  /etc/resolv.conf
    echo "nameserver $NS2" >> /etc/resolv.conf
    echo "nameserver $NS3" >> /etc/resolv.conf
    echo "nameserver $NS4" >> /etc/resolv.conf
    echo "nameserver $MASTER" >> /etc/resolv.conf
    echo "search ranger.tacc.utexas.edu tacc.utexas.edu" >> /etc/resolv.conf

else
    echo "--> Passed: First round-robin nameserver host is correct"
fi

# Verify gateway...

igot=`grep GATEWAY /etc/sysconfig/network | awk -F = '{print $2}'`

if [ "$igot" != "$GATEWAY" ];then
    echo "--> FAILED: gateway host is wrong ($igot)"
    eval perl -pi -e 's/$igot/$GATEWAY/' /etc/sysconfig/network
else
    echo "--> Passed: gateway host is correct"
fi

# Verify static routes (controlled via flat filein ~build)

igot=`diff /etc/sysconfig/static-routes $NET_DIR/static-routes | wc -l`

if [ "$igot" != "0" ];then
    echo "--> FAILED: static route file is not in sync...replacing"
    cp $NET_DIR/static-routes /etc/sysconfig/static-routes
else
    echo "--> Passed: static route is correct"
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

#-----------------------------
# Verify temporary fstab entry
#-----------------------------

igot=`grep "/export" /etc/fstab | awk -F : '{print $1}'`

if [ "$igot" !=  "$MASTER" ];then
    echo "--> FAILED: temporary fstab entry for /export is wrong"
    eval perl -pi -e 's/$igot/$MASTER/' /etc/fstab
else
    echo "--> Passed: temporary fstab entry for /export is correct"
fi

#----------------------
# Verify ramdisk entry (compute only)
#----------------------
if [ $compute_mode -eq 1 ];then
    RAMDISK=300m
    igot=`grep "/tmp" /etc/fstab | grep -v "/var/tmp" | awk -F = '{print $2}' | awk '{print $1}'`
    
    if [ "$igot" !=  "$RAMDISK" ];then
	echo "--> FAILED: ramdisk size for /tmp is incorrect"
	eval perl -pi -e 's/$igot/$RAMDISK/' /etc/fstab
    else
	echo "--> Passed: fstab ramdisk size is correct"
    fi

fi

#--------------------------
# Verify shm entry in fstab
#--------------------------

igot=`grep "/dev/shm" /etc/fstab | awk '{print $2}'`

if [ "$igot" !=  "/dev/shm" ];then
    echo "--> FAILED: /dev/shm entry is not present"
    echo "none                    /dev/shm                tmpfs   defaults        0 0" >> /etc/fstab
else
    echo "--> Passed: /dev/shm entry is present in fstab"
fi

#------------------------------------
# Verify that said shm entry is live
#------------------------------------

igot=`mount | grep "/dev/shm" | awk '{print $3}'`

if [ "$igot" !=  "/dev/shm" ];then
    echo "--> FAILED: /dev/shm entry is not actively mounted - shame on you"
    mount /dev/shm
else
    echo "--> Passed: /dev/shm entry is mounted - well done"
fi

#---------------------------
# Verify ntp setting, take 1
#------------------------

igot=`grep server /etc/ntp.conf  | awk '{print $2}'`

if [ "$igot" !=  "$MASTER" ];then
    echo "--> FAILED: ntp server host is incorrect"
    eval perl -pi -e 's/$igot/$MASTER/' /etc/ntp.conf

    if [ $IGNORE_RESTART -ne 1 ];then
	/etc/init.d/ntpd restart
    fi
else
    echo "--> Passed: ntp server host is correct"
fi

#-----------------------------
# Verify ntp setting, take 2.
#-----------------------------

if [ -e /etc/ntp/step-tickers ];then
    echo "--> FAILED: erroneous step-tickers file for ntp is present"
    rm -f /etc/ntp/step-tickers
else
    echo "--> Passed: ntp step-tickers is correct (ie. it's gone)"
fi

#------------------------
# Verify postfix setting
#------------------------

igot=`grep "relayhost = 1" /etc/postfix/main.cf  | awk '{print $3}'`

if [ "$igot" !=  "$MASTER" ];then
    echo "--> FAILED: postfix relay host is incorrect"
    eval "perl -pi -e 's/"$igot"/"$MASTER"/' /etc/postfix/main.cf"

    if [ $IGNORE_RESTART -ne 1 ];then
	/etc/init.d/postfix restart
    fi
else
    echo "--> Passed: postfix relay host is correct"
fi

# Verify syslog setting

igot=`grep "\*.\*" /etc/syslog.conf  | awk -F "@" '{print $2}'`

if [ "$igot" !=  "$MASTER" ];then
    echo "--> FAILED: syslog host is incorrect"
    eval "perl -pi -e 's/"$igot"/"$MASTER"/' /etc/syslog.conf"

    if [ $IGNORE_RESTART -ne 1 ];then
	/etc/init.d/syslog restart
    fi
else
    echo "--> Passed: syslog relay host is correct"
fi

# Verify IPoIB arp settings for ib0

igot2=`ifconfig | grep "ib0 " | awk '{print $1}'`
if [ "$igot2" != "ib0" ];then
    echo "**> Warning: Unable to verify ib0 arp settings; interface is down."
else

    igot=`sysctl net.ipv4.conf.ib0.arp_ignore | awk '{print $3}'`

    if [ "$igot" !=  "0" ];then
	echo "--> FAILED: ipv4.conf.ib0.arp_ignore is wrong"
	sysctl -q -w  net.ipv4.conf.ib0.arp_ignore=0 
    else
	echo "--> Passed: ipv4.conf.ib0.arp_ignore is correct ($igot)"
    fi
fi

if [ $compute_mode -eq 1 ];then
    if [ $CHECK_IB2 -eq 1 ];then
    
    # Verify IPoIB arp settings for ib2
	
	igot2=`ifconfig | grep ib2 | awk '{print $1}'`
	if [ "$igot2" != "ib2" ];then
	    echo "**> Warning: Unable to verify ib2 arp settings; interface is down."
	else
	    
	    igot=`sysctl net.ipv4.conf.ib2.arp_ignore | awk '{print $3}'`
	    
	    if [ "$igot" !=  "0" ];then
		echo "--> FAILED: ipv4.conf.ib2.arp_ignore is wrong"
		sysctl -q -w  net.ipv4.conf.ib2.arp_ignore=0 
	    else
		echo "--> Passed: ipv4.conf.ib2.arp_ignore is correct ($igot)"
	    fi
	fi
    fi
fi

#--------------------------------------
# Verify /etc/hosts setting for master
#--------------------------------------

igot=`grep master /etc/hosts  | awk '{print $1}'`

if [ "$igot" !=  "$MASTER" ];then
    echo "--> FAILED: /etc/hosts master IP is incorrect"
    eval perl -pi -e 's/$igot/$MASTER/' /etc/hosts
else
    echo "--> Passed: /etc/hosts master IP is correct"
fi

#---------------------------------
# Verify hostname runtime setting
#---------------------------------

if [ $compute_mode -eq 1 ];then
    igot=`echo $myhost | cut -c 1`
    if [ "$igot" != "i" ];then
	igot=`echo $myhost | perl -pe 's/\S(\d\d\d-\d\d\d)/i$1/'`
	echo "--> FAILED: cached hostname is not in IPoIB mode - updating to $igot"
	hostname $igot.ranger.tacc.utexas.edu
    else
	echo "--> Passed: cached hostname is in IPoIB mode"
    fi
fi

#--------------------------------------
# Verify local entries for login nodes
#--------------------------------------

# Login IPs are 129.114.96.2 thru 129.114.96.5

BASE=129.114.96

for i in `seq 1 4`; do
    igot=`grep "\blogin$i" /etc/hosts | awk '{print $3}'`
    if [ "$igot" != "login$i" ];then
	echo "--> FAILED: no local host entry for login$i"
	IPADDR=$BASE".$(($i+1))"
	echo "$IPADDR login$i.ranger.tacc.utexas.edu login$i" >> /etc/hosts
    else
	echo "--> Passed: login$i is present in local hosts file"
    fi
done

#---------------------------------------------
# Verify hostname setting in sysconfig/network
#---------------------------------------------

if [ $compute_mode -eq 1 ];then
    igot=`cat /etc/sysconfig/network | grep HOSTNAME | grep i*.ranger.tacc.utexas.edu | cut -d = -f 2 | cut -c 1`
    if [ "$igot" != "i" ];then
	igot=`echo $myhost | perl -pe 's/\S(\d\d\d-\d\d\d)/i$1/'`
	echo "--> FAILED: permanent hostname is not in IPoIB mode - updating sysconfig"
	perl -i -pe 's/HOSTNAME=c(\d\d\d-\d\d\d).ranger/HOSTNAME=i$1.ranger/' /etc/sysconfig/network
    else
	echo "--> Passed: permanent hostname is in IPoIB mode"
    fi

# Verify local host entry for IPoIB node

    igot=`tacc_ib_define $myhost | grep IB0 | awk '{print $3}'`
    myname=$myhost
    
    igot2=`cat /etc/hosts | grep $myname | wc -l`
    
    if [ "$igot2" != "1" ];then
	echo "--> FAILED: No local /etc/hosts entry for $myname"
	echo "--> Appending to /etc/hosts"
	echo "$igot $myname.ranger.tacc.utexas.edu $myname" >> /etc/hosts
    fi

    igot2=`cat /etc/hosts | grep $myname | awk '{print $1}'`

    if [ "$igot2" !=  "$igot" ];then
	echo "--> FAILED: /etc/hosts $myhost IP is incorrect"
	perl -i -pe 's/$igot2(\s+)$myname/$igot  $myname/' /etc/hosts
    else
	echo "--> Passed: /etc/hosts $myhost IP is correct"
    fi
fi

# Verify that tacc_sysctl is chkconfig'd on.

igot=`chkconfig --list tacc_sysctl | grep tacc_sysctl | awk '{print $1}'`

if [ "$igot" != "tacc_sysctl" ];then
    echo "--> FAILED: tacc_sysctl is not chkconfig'd on "
    chkconfig --add tacc_sysctl
else
    echo "--> Passed: tacc_sysctl is enabled in chkconfig"
fi

# Verify that tacc_ib is chkconfig'd on.

igot=`chkconfig --list tacc_ib | grep tacc_ib | awk '{print $1}'`

if [ "$igot" != "tacc_ib" ];then
    echo "--> FAILED: tacc_ib is not chkconfig'd on "
    chkconfig --add tacc_ib
else
    echo "--> Passed: tacc_ib is enabled in chkconfig"
fi

# Verify sshd max connections settings

igot=`grep "\bMaxStartups" /etc/ssh/sshd_config | awk '{print $2}'`

if [ "$igot" !=  "20" ];then
    echo "--> FAILED: sshd MaxStartups is incorrect - setting to 20 connections"
    perl -i -pe 's/#MaxStartups (\d+)/MaxStartups 20/' /etc/ssh/sshd_config
else
    echo "--> Passed: ssh can support up to 20 connections"
fi

# Verify that greceptor is chkconfig'ed off

if [ $compute_mode -eq 1 ];then
    igot=`chkconfig --list greceptor | grep "3:on"`

    if [ -n "$igot" ];then
	echo "--> FAILED: greceptor is enabled"
	chkconfig greceptor off
    else
	echo "--> Passed: greceptor is disabled in chkconfig"
    fi
fi

#------------------------------------------
# Verify the proper soft link for /opt/apps
#------------------------------------------

if [ ! -L /opt/apps ];then
    echo "--> FAILED: soft link for /opt/apps does not exist - pointing to /share/apps"
    ln -s /share/apps /opt
else
    echo "--> Passed: /opt/apps soft link exists"
fi

#-----------------------------------------
# Verify the proper ssh/pam/sge settings
#
# Temporarily commented out on 1/9/08 to try 
# and run some bigger jobs.
#-----------------------------------------

#PAMLINE="account    required     /lib/security/pam_TACC_SGE.so bypass_users=sgeadmin,karl,minyard,systest"
PAMLINE="account    required     /lib/security/pam_TACC_SGE.so bypass_users=sgeadmin,karl,minyard,systest"
# PAMLINE="account    required     /lib/security/pam_TACC_SGE.so sge_root=/opt/sge sge_execd_port=537 sge_qmaster_port=536 max_sleep=10000000"

if [ $compute_mode -eq 1 ];then

    if [ ! -s /lib/security/pam_TACC_SGE.so ];then
	echo "--> FAILED: SGE Pam module does not exist - need to install pam-sge rpm via update.sh"
    else
	if grep -q -x "$PAMLINE" /etc/pam.d/sshd ;then
	    echo "--> Passed: SGE pam module exists and is configured"
	else
	    echo "--> FAILED: pam module installed but not configured"
	    if grep -q  "/lib/security/pam_TACC_SGE.so" /etc/pam.d/sshd ; then
	    # Has the line, but with the wrong value"
		head -n -1 /etc/pam.d/sshd > /tmp/TACC_sshd_temp
		echo "$PAMLINE" >> /tmp/TACC_sshd_temp
		mv /tmp/TACC_sshd_temp /etc/pam.d/sshd
	    else
	    # No line at all"
		echo "$PAMLINE" >> /etc/pam.d/sshd
	    fi
	    chmod 600 /etc/pam.d/sshd
	fi
    fi
fi

#------------------------------------------
# Verify the desired HCA firmware version
#------------------------------------------

igot=`ibv_devinfo | grep fw_ver | awk '{print $2}'`

HCA_VERSION="2.3.000"

if [ "$igot" == "$HCA_VERSION" ];then
    echo "--> Passed: HCA firmware version at desired level ($HCA_VERSION)"
else
    echo "--> FAILED: HCA firmware is not at desired version (current=$igot)"
fi

#-------------------------------
# Verify that /share is mounted
#-------------------------------

igot=`mount | grep /share | awk '{print $5}'`

if [ "$igot" == "lustre" ];then
    echo "--> Passed: /share Lustre file system is mounted"
else
    echo "--> FAILED: /share Lustre file system is not mounted"
fi

#-------------------------------
# Verify that /work is mounted
#-------------------------------

igot=`mount | grep /work | awk '{print $5}'`

if [ "$igot" == "lustre" ];then
    echo "--> Passed: /work Lustre file system is mounted"
else
    echo "--> FAILED: /work Lustre file system is not mounted"
fi

#-------------------------------
# Verify that /scratch is mounted
#-------------------------------

igot=`mount | grep /scratch | awk '{print $5}'`

if [ "$igot" == "lustre" ];then
    echo "--> Passed: /scratch Lustre file system is mounted"
else
    echo "--> FAILED: /scratch Lustre file system is not mounted"
fi

#-----------------------------------------------
# Verify that X11 forwarding is off by default 
#-----------------------------------------------

igot=`grep "ForwardX11" /etc/ssh/ssh_config | awk '{print $2}'`

if [ "$igot" != "no" ];then
    echo "--> FAILED: ssh X11 forwarding is not disabled by default"
    perl -i -pe 's/ForwardX11\s+(\w+)/ForwardX11\t\tno/' /etc/ssh/ssh_config
else
    echo "--> Passed: ssh X11 forwarding is disabled by default"
fi


#-----------------------------------------------
# Verify that agent forwarding is off by default 
#-----------------------------------------------

igot=`grep "ForwardAgent" /etc/ssh/ssh_config | awk '{print $2}'`

if [ "$igot" != "no" ];then
    echo "--> FAILED: ssh agent forwarding is not disabled by default"
    perl -i -pe 's/ForwardAgent\s+(\w+)/ForwardAgent\t\tno/' /etc/ssh/ssh_config
else
    echo "--> Passed: ssh agent forwarding is disabled by default"
fi

#-----------------------------------------------
# Verify longer LoginGraceTime
#-----------------------------------------------

igot=`grep "^[^#]* *LoginGraceTime" /etc/ssh/sshd_config | awk '{print $2}'`

if [ "$igot" != "10m" ];then
    echo "--> FAILED: sshd LoginGraceTime incorrect"
    perl -i -pe 's/^#* *LoginGraceTime\s+(\w+)/LoginGraceTime 10m/' /etc/ssh/sshd_config
else
    echo "--> Passed: sshd LoginGraceTime is 10 minutes"
fi

#-----------------------------------------------
# Verify that crontab entry is 
#  1.  pulling 411 once an hour (remove ntp from /etc/cron.hourly/)
#  2.  ntp restart once a day
#-----------------------------------------------

RACKNUM=`echo $myhost | cut -c 3-4`
CHASSIS=`echo $myhost | cut -c 6-6`
SLOT=`echo $myhost | cut -c 8-8`

HOUR=`expr $RACKNUM % 24`
MINSHIFT=`expr 10 \* $CHASSIS`
MINUTE=`expr $MINSHIFT + $SLOT`

igot=`crontab -l | grep 411get | awk '{print $6}'`
if [ $compute_mode -eq 1 ];then
    rm -rf /etc/cron.hourly/ntp /etc/cron.hourly/RCS
    rm -f /etc/cron.daily/00-makewhatis.cron /etc/cron.daily/rpm /etc/cron.daily/yum.cron /etc/cron.daily/slocate.cron
    rm -f /etc/cron.weekly/00-makewhatis.cron /etc/cron.weekly/yum.cron
    if [ "$igot" != "/opt/rocks/bin/411get" ];then
	echo "--> FAILED: 411get pull is not in crontab"
	echo "$MINUTE * * * * /opt/rocks/bin/411get --all 1>/dev/null 2> /dev/null" > /tmp/crontab.compute
	MINUTE=`expr $MINUTE + 10`
	echo "$MINUTE $HOUR * * * /etc/rc.d/init.d/ntpd restart > /dev/null 2>&1" >> /tmp/crontab.compute

	if [ -e /tmp/crontab.compute ];then
	    crontab /tmp/crontab.compute
	else
	    "--> FAILED:  Could not create temporary crontab for computes"
	fi
    else
	igot=`crontab -l | grep ntpd | awk '{print $6}'`
	if [ "$igot" != "/etc/rc.d/init.d/ntpd" ];then
	    echo "--> FAILED: ntp restart is not in crontab"
	    echo "$MINUTE * * * * /opt/rocks/bin/411get --all 1>/dev/null 2> /dev/null" > /tmp/crontab.compute
	    MINUTE=`expr $MINUTE + 10`
	    echo "$MINUTE $HOUR * * * /etc/rc.d/init.d/ntpd restart > /dev/null 2>&1" >> /tmp/crontab.compute

	    if [ -e /tmp/crontab.compute ];then
		crontab /tmp/crontab.compute
	    else
		"--> FAILED:  Could not create temporary crontab for computes"
	    fi
	else
	    echo "--> Passed: 411get pull is enabled"
	    echo "--> Passed: ntp restart is enabled"
	fi
    fi
else 
    if [ "$igot" != "/opt/rocks/bin/411get" ];then
	echo "--> FAILED: 411get pull is not in crontab"
    
	if [ -e ~karl/compute.crontab ];then
	    crontab ~karl/compute.crontab
	else
	    echo "Unable to automatically fix crontab"
	fi
    else
	echo "--> Passed: 411get pull is enabled"
    fi
fi


#--------------------------------------
# Verify mlx4_core_log_num_qp settings
#--------------------------------------

igot=`cat /etc/modprobe.conf | grep mlx4_core | awk '{print $3}'`

if [ "$igot" != "log_num_qp=20" ];then
    echo "--> FAILED: log_num_qp mlx4_core setting not present"
    echo "options mlx4_core log_num_qp=20" >> /etc/modprobe.conf
else
    echo "--> Passed: mlx4_core num_qp setting enabled"
fi

#------------------------------------------------
# Verify mlx4_core_log_num_qp settings are active
#------------------------------------------------

igot=`ibv_devinfo --verbose | grep "max_qp:" | awk '{print $2}'`

if [ "$igot" != "1048512" ];then
    echo "--> FAILED: log_num_qp mlx4_core setting not active"
    echo "-->          reboot host to activate"
else
    echo "--> Passed: mlx4_core num_qp runtime settings are active"
fi

#------------------------------------------------
# Verify correct permissions for /dev/perfctr
#------------------------------------------------

if [ $compute_mode -eq 1 ];then
    igot=`ls -l /dev/perfctr | awk '{print $1}'`
    
    if [ "$igot" != "crw-r--r--" ];then
	echo "--> FAILED: /dev/perfctr has incorrect permissions"
	chmod 644 /dev/perfctr
    else
	echo "--> Passed: /dev/perfctr has correct permissions"
    fi
fi

#------------------------------------------------
# Verify no qlogic settings in openib.conf
#------------------------------------------------

igot=`cat /etc/infiniband/openib.conf | grep QLGC_VNIC_LOAD | awk -F = '{print $2}'`

if [ "$igot" == "yes" ];then
    echo "--> FAILED: OFED trying to load QLGC_VNIC_LOAD"
    perl -pi -e 's/QLGC_VNIC_LOAD=yes/QLGC_VNIC=no/' /etc/infiniband/openib.conf
else
    echo "--> Passed: OFED is not loading QLGC driver"
fi


#------------------------------------------------
# Make sure ethernet HWADDR is commented out
#------------------------------------------------

perl -pi -e 's/^HWADDR/#HWADDR/' /etc/sysconfig/network-scripts/ifcfg-eth0


