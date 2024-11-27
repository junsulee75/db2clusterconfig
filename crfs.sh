#!/bin/bash

#source `pwd`/conf ## for /bin/ksh
source config.ini # use /bin/bash for reading from the current directory
source jscommon.sh

# to be flexible to take parameters 
if [ -z "$1" ]; then
    db2_fs_dir="/db2fs" # default
else 
    db2_fs_dir="$1"
fi

if [ -z "$2" ]; then
    DEVNAME="sda"
else 
    DEVNAME="$2"
fi


createFS(){
    print1 "creating a file system to iscsi shared device"
    for HOST in $db2hosts
	do
		disp_msglvl2 "create $db2_fs_dir on $HOST..."
        ssh $SSH_NO_BANNER $HOST  mkdir -p $db2_fs_dir
    done
    
	disp_msglvl2 "create a file system and format /dev/$DEVNAME on $headhost ..."
    mkfs.ext4 /dev/$DEVNAME;cmdRetChk
        
}

addFstab(){
    UUID=$(blkid /dev/$DEVNAME |awk '{print $2;}' |sed 's/\"//g')
    LINE2ADD="$UUID $db2_fs_dir ext4 acl,user_xattr,noauto 0 0"
    
    for HOST in $db2hosts
	do
		disp_msglvl2 "Adding to /etc/fstab on $HOST..."
        ssh $SSH_NO_BANNER $HOST "sed -i '/$UUID/d' /etc/fstab" # delete if there is same UUID line
        ssh $SSH_NO_BANNER $HOST "echo "$LINE2ADD" >> /etc/fstab"
        ssh $SSH_NO_BANNER $HOST "grep "$UUID" /etc/fstab"
    done
}

mountPri(){
	disp_msglvl2 "Mount the created file system on the active host $headhost..."
    ssh $SSH_NO_BANNER $headhost "mount $db2_fs_dir";cmdRetChk
    ssh $SSH_NO_BANNER $headhost "mount |grep $db2_fs_dir"

} 

# optional : for any existing DB
#db2cm -add -dbMount $DBNAME -partition 0 -instance $INST_USER

createFS
addFstab
mountPri
