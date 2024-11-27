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

if [ ! -d "$db2_fs_dir" ]; then
	echo "$db2_fs_dir directory does not exist or not accessible. Check and try again. Existing !!"
	logger_error "$db2_fs_dir directory does not exist or not accessible. Check and try again. Existing !!"
	exit 1
fi



# https://www.ibm.com/docs/en/db2/11.5?topic=option-creating-pacemaker-managed-mutual-failover-db2-instance

createUser(){

	for HOST in $db2hosts
	do
		# UID and GID of the instance user and db2iadm1 group should be same on both hosts.
		# Therefore, we set the id number hoping it does not exist. 
		disp_msglvl2 "create user on $HOST..."
		ssh $SSH_NO_BANNER $HOST groupadd -g 1000 db2iadm1
		ssh $SSH_NO_BANNER $HOST groupadd -g 1001 db2fadm1

		# KC example shows ksh
		#ssh $SSH_NO_BANNER $HOST "useradd -u 1000 -g db2iadm1 -m -d /home/$INST_USER -s /usr/bin/ksh $INST_USER"  # let's not give id, sometimes failure with conflict   
		#ssh $SSH_NO_BANNER $HOST "useradd -u 1001 -g db2fadm1 -m -d /home/db2fenc1 -s /usr/bin/ksh db2fenc1"  

		# I prefer to set bash rather than ksh. KC example shows ksh but I beleieve bash should be fine. 
		#When you execute a remote command via ssh (ssh user@host command), it starts a non-login, non-interactive shell.
		#In ksh, this means neither ~/.profile nor ~/.kshrc is sourced unless explicitly configured.
		#With bash, a non-login shell would read ~/.bashrc if properly configured. 
		#Therefore, problem to run command by remote ssh for remote user using ksh      

		ssh $SSH_NO_BANNER $HOST "useradd -u 1000 -g db2iadm1 -m -d /home/$INST_USER $INST_USER"  # let's not give id, sometimes failure with conflict   
		ssh $SSH_NO_BANNER $HOST "useradd -u 1001 -g db2fadm1 -m -d /home/db2fenc1 db2fenc1"  

		#ssh $HOST passwd $INST_USER
    	#ssh $HOST passwd db2fenc1

		echo " setting password with default password |$USERPW|. Change if you want later " 	
		ssh $SSH_NO_BANNER $HOST "echo "$INST_USER:$USERPW" |sudo chpasswd"  # let's set password without prompt   
		ssh $SSH_NO_BANNER $HOST "echo "db2fenc1:$USERPW" |sudo chpasswd"  # let's set password without prompt   

	done
}

chgHomeDirPrimary(){

	print1 "Change home directory for $INST_USER on $headhost"
	mkdir -p $db2_fs_dir/$INST_USER
	chown -R ${INST_USER}.db2iadm1 $db2_fs_dir
	touch /home/$INST_USER/.profile
	touch /home/$INST_USER/.kshrc
	
	print2 "Change home directory to $db2_fs_dir/$INST_USER"
	usermod -d $db2_fs_dir/$INST_USER $INST_USER
	
	print2 "copy .profile and .kshrc to $db2_fs_dir/$INST_USER"
	cp -f /home/db2inst1/.profile $db2_fs_dir/$INST_USER
	cp -f /home/db2inst1/.kshrc $db2_fs_dir/$INST_USER
	# some more just in case
	cp -f /home/db2inst1/.bashrc $db2_fs_dir/$INST_USER
	cp -f /home/db2inst1/.bash_profile $db2_fs_dir/$INST_USER
	cp -f /home/db2inst1/.mkshrc $db2_fs_dir/$INST_USER
	cp -f /home/db2inst1/.zshrc $db2_fs_dir/$INST_USER
	
	chown -R ${INST_USER}.db2iadm1 $db2_fs_dir  # chown again as above copy commands create root permission files.   
	echo
	ls -al $db2_fs_dir/$INST_USER
	echo
	grep $INST_USER /etc/passwd

}


sshkeyGen(){
	
	#sudo -u $INST_USER /bin/ssh-keygen -t rsa  # this needs user intervention. Thinking other way below.  

	# create ssh key for primary host only as home direcory will be shared.     
	for host in $headhost  ## only need to set pwless between db2 hosts
	do
	
		disp_msglvl2 "Generate SSH key for $INST_USER on $host"
		# example 
		# ssh jspmtest2 "sudo -u jslee /bin/ssh-keygen -t rsa -b 4096 -N \"\" -f ~jslee/.ssh/id_rsa"  ## should use -N "" to -N \"\" .Otherwise too many parameter error
		ssh $SSH_NO_BANNER $host "sudo -u $INST_USER /bin/ssh-keygen -t rsa -b 4096 -N \"\" -f ~$INST_USER/.ssh/id_rsa"  
		
		# also create authorized file with correct permission in advance so that next logic can add keys to this file without creating file by root
		ssh $SSH_NO_BANNER $host "sudo -u $INST_USER touch ~$INST_USER/.ssh/authorized_keys"
		ssh $SSH_NO_BANNER $host "sudo -u $INST_USER chmod 600 ~$INST_USER/.ssh/authorized_keys"
		
		ssh $SSH_NO_BANNER $host "sudo -u $INST_USER ls -al ~$INST_USER/.ssh"

	done	

}

setPWLess(){
	# This function is all about adding id_rsa.pub to instance user authorized_keys 
	# In shared storage environment, currently file system is mounted to the first host (headhost). 
	# Therefore, doign theses
	# 1. root user public key from all DB2 hosts to the instance user authorized key of the headhost. ( Current mounted host)
	# 2. instance user public key to the instance user authorized key of the headhost. ( Current mounted host) 
	# 3. Add instance user public key as other Db2 host names. Copy the current public key line and replace the hostname then add.   
	

	disp_msglvl1 "passwordless login setting from all hosts' root/$INST_USER  to  $INST_USER "
	
	for fromhost in $db2hosts  ## only need to set pwless between db2 hosts
	do
		for tohost in $headhost  # targethost is the current host only   
		do 
			disp_msglvl2 "Copy root user id_rsa.pub from $fromhost into $INST_USER authorized_keys of $tohost"   
			ROOT_KEY2COPY=`ssh $SSH_NO_BANNER $fromhost cat /root/.ssh/id_rsa.pub`
			#echo $ROOT_KEY2COPY   
			ssh $SSH_NO_BANNER $tohost "echo $ROOT_KEY2COPY >> ~$INST_USER/.ssh/authorized_keys" 
			#ssh $SSH_NO_BANNER $tohost "cat ~$INST_USER/.ssh/authorized_keys" 
						
		done		
	done

	print2 "authorized keys after adding root user keys of both hosts"
	ssh $SSH_NO_BANNER $headhost "cat ~$INST_USER/.ssh/authorized_keys" 

	INSTUSER_KEY2COPY=`ssh $SSH_NO_BANNER $headhost cat ~$INST_USER/.ssh/id_rsa.pub`

	for HOST in $db2hosts
	do
		disp_msglvl2 "Copy $INST_USER user's id_rsa.pub from $HOST into $INST_USER authorized_keys of $headhost" 
		if [ "$HOST" = "$headhost" ]; then
			echo $INSTUSER_KEY2COPY 
			ssh $SSH_NO_BANNER $headhost "echo $INSTUSER_KEY2COPY >> ~$INST_USER/.ssh/authorized_keys" 	
		else # In single Active/standby, only one 2nd host. using else in case there would be more. ex)DPF
			echo "$headhost|$HOST"
			INSTUSER_KEY2COPY_CHG=$(echo $INSTUSER_KEY2COPY | sed "s/$headhost/$HOST/g")
			ssh $SSH_NO_BANNER $headhost "echo $INSTUSER_KEY2COPY_CHG >> ~$INST_USER/.ssh/authorized_keys"
			
		fi
	done 
		  
	print2 "authorized keys after adding $INST_USER keys from both hosts"
	ssh $SSH_NO_BANNER $tohost "cat ~$INST_USER/.ssh/authorized_keys" 


}

testPWLess(){


	## It's enough to test from the current host to current host/remote host. 
	## Then we can run remote command to root and db2inst1 user without prompt. Mainly run the commands from the current 1st host.   
	disp_msglvl2 "Passwordless ssh test into $INST_USER of $headhost"   
	ssh $SSH_NO_BANNER $INST_USER@$headhost "hostname;id;date"	
}

createInstance(){

	HOST="$1" # need hostname input for this function. 
	disp_msglvl2 "create instance on $HOST..."
	ssh $SSH_NO_BANNER  $HOST "$DB2_INSTALL_PATH/instance/db2icrt -p $PORT -u db2fenc1 $INST_USER"
	if [ $? -ne 0 ]; then 
		logger_error "Instance creation on $HOST failed. Exiting"
		exit 1
	fi
	# Let's backup db2nodes.cfg after instance creation
	disp_msglvl2 "backup db2node.cfg to $db2_fs_dir"
	ssh $SSH_NO_BANNER  $HOST "cp -f $db2_fs_dir/$INST_USER/sqllib/db2nodes.cfg $db2_fs_dir/db2nodes.cfg.$HOST"
	ssh $SSH_NO_BANNER  $HOST "chown $INST_USER.db2iadm1 $db2_fs_dir/db2nodes.cfg.$HOST"
}

fsMove(){
	
	fs2move="$1"
	fromhost="$2"
	tohost="$3"

	print1 "Move file system $fs2move from $fromhost to $tohost"

	
	print2 "unmount $fs2move from $fromhost"
	ssh $SSH_NO_BANNER $fromhost "umount $fs2move";cmdRetChk
	ssh $SSH_NO_BANNER $fromhost "mount |grep $fs2move"
	
	print2 "mount $fs2move on $tohost"
	ssh $SSH_NO_BANNER $tohost "mount $fs2move";cmdRetChk
	ssh $SSH_NO_BANNER $tohost "ls $fs2move/$INST_USER/"
}

chgHomeDirStdby(){
	print1 "Change home directory for $INST_USER on $secondhost"
	ssh $SSH_NO_BANNER $secondhost "chown -R ${INST_USER}.db2iadm1 $db2_fs_dir"
	
	print2 "Change home directory to $db2_fs_dir/$INST_USER"
	ssh $SSH_NO_BANNER $secondhost "usermod -d $db2_fs_dir/$INST_USER $INST_USER"
	
	#ssh jstest2.fyre.ibm.com "[ -d /db2fs/db2inst1/sqllib ]" && ssh jstest2.fyre.ibm.com "ls /db2fs/db2inst1/sqllib"
	print2 "remove sqllib "
	SQLLIBDIR="$db2_fs_dir/$INST_USER/sqllib"
	ssh $SSH_NO_BANNER $secondhost "[ -d \"$SQLLIBDIR\" ]" && ssh $SSH_NO_BANNER $secondhost "rm -rf $SQLLIBDIR"
	
}

startInstance(){

	if [ -z "$1" ]; then
		HOST="$headhost" # default 
	else 
		HOST="$1"
	fi	
	print1 "start DB2 instance on $HOST"
	SQLLIBDIR="$db2_fs_dir/$INST_USER/sqllib"
	
	# any better way ? 
	print2 "copy db2nodes.cfg"
	ssh $SSH_NO_BANNER $HOST "[ -d \"$SQLLIBDIR\" ]" && ssh $SSH_NO_BANNER $INST_USER@$HOST "cp -f $db2_fs_dir/db2nodes.cfg.$HOST $SQLLIBDIR/db2nodes.cfg";cmdRetChk # start if sqllib directory
	#JSTODO : file existence check. $db2_fs_dir/db2nodes.cfg.$HOST  , db2nodes.cfg content check : 

	print2 "start instance on $HOST"
	ssh $SSH_NO_BANNER $INST_USER@$HOST "db2start";cmdRetChk

	#ssh $SSH_NO_BANNER $INST_USER@$HOST "source ~/.profile && db2start";cmdRetChk # if remote user is using ksh, .profile is not sourced doing ssh   
}

createUser
chgHomeDirPrimary
sshkeyGen
setPWLess
testPWLess
createInstance $headhost  # create instance in primary(head) host while the shared file system is mounted there.  
fsMove $db2_fs_dir $headhost $secondhost
chgHomeDirStdby
createInstance $secondhost  # Create the Db2 instance on the second host. This is needed since some of the instance files are created on the local disk, such as the Db2 registry
fsMove $db2_fs_dir $secondhost $headhost  # File system back to primary host 
startInstance $headhost # start DB2 instance on primary host