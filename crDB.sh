#!/bin/bash
## create DB for an instance on a host
## junsulee@au1.ibm.com
##

source config.ini # use /bin/bash for reading from the current directory
source jscommon.sh

# to be flexible to take parameters 
if [ -z "$1" ]; then
    HOST="$headhost" # default : Current host if not specified
else 
   $HOST="$1"
fi

USER_HOME=$(eval echo ~$INST_USER)
echo "Home directory of $INST_USER : |$USER_HOME|"

ACTIVE_LOG_PATH="$USER_HOME/active_log_path"
ARCHIVE_LOG_PATH="$USER_HOME/archive_log_path"

BACKUP_PATH="$USER_HOME/backup"

function createDB {

        PRIMARY_HOST="$HOST"

	print2 "Check if DB2 instance is up on $HOST (Running db2pd -edus)"
	ssh $SSH_NO_BANNER $INST_USER@$headhost "db2pd -edus"
       	if [ $? -ne 0 ]; then
	        echo "DB2 instance is not started. Trying to start"
                ssh $SSH_NO_BANNER $INST_USER@$headhost "db2stop force"
                ssh $SSH_NO_BANNER $INST_USER@$headhost "db2start";cmdRetChk  # if no success, exit.   
        fi

        disp_msglvl2 "Creating DB $DBNAME on $PRIMARY_HOST..."
        if [ $DBNAME  = "sample" ]; then
                ssh $SSH_NO_BANNER $INST_USER@$PRIMARY_HOST db2sampl
        else
                ssh $SSH_NO_BANNER $INST_USER@$PRIMARY_HOST "db2 -v create db $DBNAME"
        fi

        disp_msglvl2 "Create active log directory $ACTIVE_LOG_PATH" 
        ssh $SSH_NO_BANNER $INST_USER@$PRIMARY_HOST  mkdir -p $ACTIVE_LOG_PATH
        disp_msglvl2 "Create archive log directory $ARCHIVE_LOG_PATH" 
        ssh $SSH_NO_BANNER $INST_USER@$PRIMARY_HOST  mkdir -p $ARCHIVE_LOG_PATH

        disp_msglvl2 "DB configuration on $PRIMARY_HOST"    
        ssh $SSH_NO_BANNER $INST_USER@$PRIMARY_HOST "db2 -v update db cfg for $DBNAME using NEWLOGPATH $ACTIVE_LOG_PATH"
        ssh $SSH_NO_BANNER $INST_USER@$PRIMARY_HOST "db2 -v update db cfg for $DBNAME using LOGARCHMETH1 DISK:$ARCHIVE_LOG_PATH"
        #db2 restore db $DBNAME

        ssh $SSH_NO_BANNER $INST_USER@$PRIMARY_HOST  "db2 -v backup db $DBNAME to /dev/null"
        ssh $SSH_NO_BANNER $INST_USER@$PRIMARY_HOST  "db2 -v activate db $DBNAME"

}

createDB