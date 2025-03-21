#!/bin/bash

#source `pwd`/conf ## for /bin/ksh
source config.ini # use /bin/bash for reading from the current directory
source jscommon.sh

# to be flexible to take parameters 
if [ -z "$1" ]; then
	MODE="" # no input or invalid input would be HADR
else 
    MODE="$1" # shared
fi

if [ "$MODE" = "shared" ];then
	print1 "Check if DB2 instance is up on $headhost (Running db2pd -edus)"
	ssh $SSH_NO_BANNER $INST_USER@$headhost "db2pd -edus"
	cmdRetChk
fi


USER_HOME=$(eval echo ~$INST_USER)
echo "Home directory of $INST_USER : |$USER_HOME|"

chkDb2cm(){

	if [ ! -f $USER_HOME/sqllib/bin/db2cm ] ; then
		disp_msglvl2 "Error, the file $USER_HOME/sqllib/bin/db2cm does not exist..... Ensure pacemaker installation has done correctly.  "
		exit 1
	fi
	disp_msglvl2 "The file $USER_HOME/sqllib/bin/db2cm exists. So we continue... "
}

createDomain(){

    disp_msglvl1 "creating new domain..."
	echo "After creation, NIC resource may show Stopped status. It's expected. It will be started after creating instance resource later on"
	$USER_HOME/sqllib/bin/db2cm -cluster -create -domain db2domain -host $PRIMARY_HOST -publicEthernet eth0 -host $STANDBY_HOST -publicEthernet eth0 -remote_cmd "ssh $SSH_NO_BANNER" 
	crm status
}

createInstanceResource(){

    disp_msglvl1 "creating instance resources..."
	$USER_HOME/sqllib/bin/db2cm -create -instance $INST_USER -host $PRIMARY_HOST -remote_cmd "ssh $SSH_NO_BANNER" 
	$USER_HOME/sqllib/bin/db2cm -create -instance $REMOTE_INST -host $STANDBY_HOST -remote_cmd "ssh $SSH_NO_BANNER" 
	crm status
}

createPartition(){

	if [ -z "$1" ]; then
		echo "partition number is not specified. Exiting !! "
		exit 1
	fi
    disp_msglvl1 "creating partition resources for partition $1"
	$USER_HOME/sqllib/bin/db2cm -create -partition $1 -instance $INST_USER -remote_cmd "ssh $SSH_NO_BANNER" 
	crm status
}

createDBResource(){

    disp_msglvl1 "creating DB resource..."
	$USER_HOME/sqllib/bin/db2cm -create -db $DBNAME -instance $INST_USER -remote_cmd "ssh $SSH_NO_BANNER" 
	crm status
}

createVIP(){

	PARTNUM="$1" # used only for shared

	if [ "$VIP" = "123.123.123.123" ] || [ -z "$VIP" ] ; then   # not changed or not set

		# If fyre provisioned, I know what to do   
		hostname | grep fyre >/dev/null
		if [ $? -eq 0 ] ; then  # This is for IBM fyre provisioned system. It will grab "eth0" for internal ip address. From tests, no need to specify iface. flannel will use it automatically.   
			ipaddr=$(ip addr | grep "inet 10.*dynamic" | awk '{print $2}' | sed 's/\/.*//' )
			subnetMask=$(ip addr | grep "inet 10.*dynamic" | awk '{print $2}' | sed 's/.*\///' )
			print2 "GOLANG(freeip) : Running other program to find an available IP address under the same subnet of IP $ipaddr/$subnetMask"
			OUTPUT=$(./freeip/freeip_$(uname -p) "$ipaddr" "$subnetMask")
			if [ $? -eq 0 ]; then
				VIP="$OUTPUT"
				echo "OK. Found the available IP address $VIP . Will use it as VIP\n\n"
			else
				echo "Failed to find an available IP address for VIP. Find and try again manually later. SKipping VIP configuration...\n\n"
				return 1
			fi
		else
			echo "You haven't set the correct VIP in config.ini. Find and try again manually later. SKipping VIP configuration...\n\n" 
			return 1
		fi
	
	fi



    disp_msglvl1 "creating VIP resource..."
	if [ "$MODE" = "shared" ]; then 
		$USER_HOME/sqllib/bin/db2cm -create -primaryVIP $VIP -partition $1 -instance $INST_USER -remote_cmd "ssh $SSH_NO_BANNER" 
	else
		$USER_HOME/sqllib/bin/db2cm -create -primaryVIP $VIP -db $DBNAME -instance $INST_USER -remote_cmd "ssh $SSH_NO_BANNER" 
	fi
	## TODO : fix error Error: the VIP address 10.11.71.150 is not within the same subnet as host with IP 10.11.100.236
	##        In this case, the IP 10.11.100.50 worked.   
	crm status
    disp_msglvl2 "IP information...check secondary VIP $VIP is added to the network resource" 
	ip addr
	
}
createQdevice(){

   
	# Cluster 001 : For Redhat 8.8 and DB2 V11.5.8.0, creating qdevice asks the prompt like below.  
	#The authenticity of host 'pcmktest1 (10.11.112.80)' can't be established.
	#ECDSA key fingerprint is SHA256:R5dPDq/JovLwiKAwU3zDWo19eNudqvqUssEdZM5azFs.
	#Are you sure you want to continue connecting (yes/no/[fingerprint])? yes   <===

	# To suppress the prompt, running ssh manually in advance. 
	if [[ "$ID" == "rhel" && "$VERSION_ID" == "8.8" ]]; then  ## ## default v11.5.8 for Redhat 8.8
		disp_msglvl2 "Passwordless ssh test to $PRIMARY_HOST. To add known_hosts" 
		ssh -o StrictHostKeyChecking=no root@${PRIMARY_HOST} date;cmdRetChk
	fi
		

    disp_msglvl2 "creating Qdevice..."
	$USER_HOME/sqllib/bin/db2cm -create -qdevice $QUORUM_HOST -remote_cmd "ssh $SSH_NO_BANNER" 
	sleep 10
	/usr/sbin/corosync-qdevice-tool -s

    disp_msglvl2 "ssh $QUORUM_HOST corosync-qnetd-tool -l"
	ssh $SSH_NO_BANNER $QUORUM_HOST corosync-qnetd-tool -l

}

cmList(){
	disp_msglvl2 "Pacemaker cluster configuration : db2cm -list"
	$USER_HOME/sqllib/bin/db2cm -list
}	

## common
chkDb2cm
createDomain

if [ "$MODE" = "shared" ]; then
	createPartition 0	
	createVIP 0
else # HADR : default
	createInstanceResource
	createDBResource
	createVIP
fi

createQdevice
cmList