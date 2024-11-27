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
    menu.py 1,1,6   # Prereq. packages installation
    menu.py 1,2,6    # Db2 installation

    menu.py 2,1,3    # iscsi target
    menu.py 2,2,3    # iscsi initiators

    menu.py 3,1,4    # create shared file system
    menu.py 3,2,4    # create user and instance   
    menu.py 3,3,4    # pacemaker setup for shared storage   

    menu.py 4,1,2    # Creating DB (optional)    
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
