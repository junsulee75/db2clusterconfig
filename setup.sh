#!/bin/bash

export PROMPT=0


hadrPacemaker(){
    menu.py 1,1,6   # Prereq. packages installation
    menu.py 1,2,6    # Db2 installation
    menu.py 1,3,6    # create instance user and DB2 instance
    menu.py 1,4,6    # hadr configuration 
    menu.py 1,5,6    # pacemaker setup  
}

sharedPacemaker(){
    menu.py 2,1,9   # Prereq. packages installation
    menu.py 2,2,9    # Db2 installation

    menu.py 2,3,9    # iscsi target
    menu.py 2,4,9    # iscsi initiators

    menu.py 2,5,9    # create shared file system
    menu.py 2,6,9    # create user and instance   
    menu.py 2,7,9    # pacemaker setup for shared storage   

    menu.py 2,8,9    # Creating DB (optional)    
}

case "$1" in

	shared )  
		echo;echo;echo "Configuring Active/standby shared storage using pacemaker. ";echo;echo
        sharedPacemaker
    ;;

    * ) 
		echo;echo;echo "By default, configuring 2 nodes HADR / 1 node qurom node using pacemaker. ";echo;echo
        hadrPacemaker
	;;

esac 
