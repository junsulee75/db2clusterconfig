#!/bin/bash

mode=$1    # mode to run

#source `pwd`/conf ## for /bin/ksh
source config.ini # use /bin/bash for reading from the current directory
source jscommon.sh

targetIQN=""   # target IQN name 
FWChkCmd="firewall-cmd --list-all"	 

getTargetIQN(){
	targetIQN=`ssh $SSH_NO_BANNER $iscsihost targetcli '/iscsi/ ls'|grep iqn|grep -v 'Mapped LUNs'|awk '{print $2}'`  
	#if [ -n "$iqn_name" ]; then  # NULL check
	if [[ $targetIQN == "iqn"* ]]; then  # check if iqn_name start with the pattern "ipn".  
		disp_msglvl2 " $iscsihost : iqn (iSCSI Qualified Name) of the target node : $targetIQN"		
	else
		disp_msglvl2 " can't get iqn from target node or wrong pattern name. iqn=$targetIQN. Check iscsi target configuration again.  Exit !!! "	
		exit
	fi
}

iscsiConfChk(){
	disp_msglvl1 "$iscsihost : Configuration on iscsi target : targetcli ls "   
	ssh $SSH_NO_BANNER $iscsihost targetcli ls
	disp_msglvl2 "iqn (iSCSI Qualified Name) of the target node : $targetIQN"		
	disp_msglvl2 "IP addresss of the target node : $ISCSI_TARGET_IP"		
	
	for HOST in $pshost
	do
		disp_msglvl1 "ISCSI chek on initiator host : $HOST "		
	 	fileIQN=`ssh $SSH_NO_BANNER $HOST cat /etc/iscsi/initiatorname.iscsi|awk -F= '{print $2}'`
		echo " $HOST : get IQN from /etc/iscsi/initiatorname.iscsi  : $fileIQN"
		
		disp_msglvl2 " $HOST :  fdisk -l |grep -A 4 sda "
		ssh $SSH_NO_BANNER $HOST fdisk -l |grep -A 4 sda    

		disp_msglvl2 " $HOST : ls /dev/sda " 
		ssh $SSH_NO_BANNER $HOST ls /dev/sda  

		disp_msglvl2 " $HOST : lsblk "
		ssh $SSH_NO_BANNER $HOST lsblk  
		
		disp_msglvl2 " $HOST : systemctl status iscsid "
		ssh $SSH_NO_BANNER $HOST systemctl status iscsid 
		
		disp_msglvl2 " $HOST : systemctl status iscsi "
		ssh $SSH_NO_BANNER $HOST systemctl status iscsi 
		
		disp_msglvl2 " $HOST : iscsiadm -m session -P 0 "
		ssh $SSH_NO_BANNER $HOST iscsiadm -m session -P 0 
	
		disp_msglvl2 " $HOST : iscsiadm -m session -P 3 "
		ssh $SSH_NO_BANNER $HOST iscsiadm -m session -P 3

		disp_msglvl2 " $HOST : $FWChkCmd "
		ssh $SSH_NO_BANNER $HOST $FWChkCmd

		disp_msglvl2 " $HOST : dmesg |grep sda "
		ssh $SSH_NO_BANNER $HOST dmesg |grep sda 
		
		disp_msglvl2 " $HOST : journalctl -xe | grep iscsi "
		ssh $SSH_NO_BANNER $HOST journalctl -xe | grep iscsi
	done	
}

restartISCSIService(){
	for HOST in $pshost
	do
		disp_msglvl2 "$HOST : start iscsi initiator service"   
		ssh $SSH_NO_BANNER $HOST service iscsi stop
		ssh $SSH_NO_BANNER $HOST service iscsid stop
		ssh $SSH_NO_BANNER $HOST service iscsid start
		ssh $SSH_NO_BANNER $HOST service iscsi start
		ssh $SSH_NO_BANNER $HOST service iscsi status
		ssh $SSH_NO_BANNER $HOST fdisk -l
	done

}

initDisk(){   ## wipe out disk blocks   
        disp_msglvl2 "$HOST : Wiping out disk blocks : dd if=/dev/zero of=/dev/sda bs=1M count=100"
        dd if=/dev/zero of=/dev/sda bs=1M count=100; cmdRetChk

        disp_msglvl2 "$HOST : fdisk -l" 
        for HOST in $pshost
        do
                ssh $SSH_NO_BANNER $HOST fdisk -l
        done

}

initDiskAll(){   ## wipe out disk blocks
        for HOST in $pshost
        do
                disp_msglvl2 "$HOST : Wiping out disk blocks : dd if=/dev/zero of=/dev/sda bs=1M count=1000"
                ssh $SSH_NO_BANNER $HOST dd if=/dev/zero of=/dev/sda bs=1M count=100; cmdRetChk
        done

        disp_msglvl2 "$HOST : fdisk -l"
        for HOST in $pshost
        do
                ssh $SSH_NO_BANNER $HOST fdisk -l
        done

}

#getTargetIQN  # if fail on this, should exit 

addDisk(){
	DISKNAME="$1"
	DISKSIZE="$2"
	print1 "Adding disk $DISKNAME with ${DISKSIZE}GB"
	CMD="targetcli '/backstores/fileio create ${DISKNAME} /work/iscsi/${DISKNAME}.ext ${DISKSIZE}GB write_back=false'"
	print2 " $iscsihost : creating backstore : $CMD"
	ssh $SSH_NO_BANNER $iscsihost mkdir -p /work/iscsi
	ssh $SSH_NO_BANNER $iscsihost $CMD
	echo
	ssh $SSH_NO_BANNER $iscsihost targetcli ls

	## test delete : rm -f /work/iscsi/tbdev1.txt;targetcli /backstores/fileio delete tbdev1;targetcli ls
	NEWIQN="iqn.$(date +"%Y-%m").com.ibm:$DISKNAME"
	CMD="targetcli /iscsi/ create $NEWIQN"
	print2 " $iscsihost : creating new target with IQN $NEWIQN : $CMD"
	ssh $SSH_NO_BANNER $iscsihost $CMD
	echo
	ssh $SSH_NO_BANNER $iscsihost targetcli ls
	echo
	ssh $SSH_NO_BANNER $iscsihost "ls -l /work/iscsi"

	CMD="targetcli '/iscsi/$NEWIQN/tpg1/portals/ create $ISCSI_TARGET_IP'"
	print2 " $iscsihost : creating portal with IQN $NEWIQN : $CMD"
	ssh $SSH_NO_BANNER $iscsihost $CMD
	echo
	##ssh $SSH_NO_BANNER $iscsihost targetcli ls

	CMD="targetcli '/iscsi/$NEWIQN/tpg1/luns create /backstores/fileio/$DISKNAME'"
	print2 " $iscsihost : creating LUN with IQN $NEWIQN : $CMD"
	ssh $SSH_NO_BANNER $iscsihost $CMD
	echo
	##ssh $SSH_NO_BANNER $iscsihost targetcli ls

	print2 " $iscsihost : save configuration"
	ssh $SSH_NO_BANNER $iscsihost targetcli saveconfig

	# Assume initiator was created already. So do not run '/sbin/iscsi-iname' to create
	for HOST in $pshost
	do
	 	fileIQN=`ssh $SSH_NO_BANNER $HOST cat /etc/iscsi/initiatorname.iscsi|awk -F= '{print $2}'`
		CMD="targetcli '/iscsi/$NEWIQN/tpg1/acls create $fileIQN'"
		print2 " $iscsihost : creating acls for $HOST : $CMD"
		ssh $SSH_NO_BANNER $iscsihost $CMD
		if [ $? -ne 0 ]; then
			echo "$iscsihost : targetcli creation failure for $HOST. Exit.."
   			exit 1
		else
		 	   echo "$iscsihost : targetcli creation SUCCESS for $HOST. !!! "
		fi
	done
	echo
	ssh $SSH_NO_BANNER $iscsihost targetcli ls

	for HOST in $pshost
	do
		disp_msglvl2 " $HOST : discover target IQN names"
		ssh $SSH_NO_BANNER $HOST "iscsiadm -m discovery -t st -p $ISCSI_TARGET_IP" # JSTODO : better to check $NEWIQN is listed

		disp_msglvl2 "$HOST : login to target $NEWIQN"
		ssh $SSH_NO_BANNER $HOST  iscsiadm -m node -T $NEWIQN -l
		disp_msglvl2 "$HOST : auto start setup setting "
		ssh $SSH_NO_BANNER $HOST  iscsiadm -m node -T $NEWIQN -o update -n node.startup -v automatic
		ssh $SSH_NO_BANNER $HOST  iscsiadm -m node -T $NEWIQN -o update -n node.conn[0].startup -v automatic

		disp_msglvl2 "$iscsihost : save the configuration for $HOST "
		ssh $SSH_NO_BANNER $iscsihost targetcli saveconfig
	done

	echo
	ssh $SSH_NO_BANNER $iscsihost targetcli ls

	print1 "Check disks : fdisk -l"
	for HOST in $pshost
	do
		print2 " $HOST : fdisk -l"
		ssh $SSH_NO_BANNER $HOST fdisk -l
	done

}

case $mode in
	restart )
		restartISCSIService
		;;
	check )
		iscsiConfChk
		;;
	zeroinit )
		initDisk
		;;
	adddisk )
		addDisk $2 $3   # diskname size   ex) tbdev1 5
		;;
	* ) 
		echo "Missing input operation : $0 [check|restart|zeroinit|adddisk]"
		;;
esac

