# Db2 hadr on pacemaker automatic configurator

Fully automated scripts for creating DB2 with pacemaker cluster environment.   
The script supports two types.   
- DB2 HADR with pacemaker
- Active standby with shared storage. (DB2 manual calls it 'Mutual takeover' )   

## Contents

- [Db2 hadr on pacemaker automatic configurator](#db2-hadr-on-pacemaker-automatic-configurator)
  - [Contents](#contents)
  - [Objectives](#objectives)
  - [Steps](#steps)
  - [Reference](#reference)


## Objectives 

The scripts assume the following things in advance. 
- Passwordless ssh root user login is set between hosts.   
  (IBM Fyre provisioned system has set already.)    
- For automated Db2 installation images download by `curl`, I configured my own web server containing donwloaded Db2 images.  
  You may use the same way with your own web server or just change config.ini and 2_db2_install.sh to set file path manually.   
   
- You know which VIP address to use. (Need to figure out an unused IP by yourself)       

[Go to content](#contents)


## Steps  

1. Prepare 3 Redhat hosts.   
   
Example)   
- Redhat 8.8 or 8.10       
- Size : Any   
- Quantity : 3        

Following Db2 version will be installed by default. (Tested combination)   

> Currently, only following combinations are tested and supported.     

DB2 V11.5.9.0 on Redhat 8.10    
DB2 V11.5.8.0 on Redhat 8.8    

If you want to install other versions, edit config.ini    
 
> IBMers can use internal fyre [quickburn](https://fyre.svl.ibm.com/quick).      

2. Download the scripts or clone this repository to the 1st host by root user         


3. Edit the following line with the your hostnames and preferred VIP on `config.ini` file.    

```
##########################################################
## Must set area ! Only thing you need to configure manually in most cases
##########################################################

# Set virtual IP address to use. It should an unused IP within the same subnet and set. If not specified, script will try to get a random free IP address
VIP="123.123.123.123"     ## Virtual IP address to use. Again !! please change this with an appropriate one. Otherwise, it will skip creating VIP resource.   
....

```    

> NOTE : Check the current IP addresses/subnet and specify VIP in the same subnet.   
> For IBM internal Fyre environment,   
> this script will pick up an available VIP automatically if the parameter in config.ini is not changed.   

4. Execute script

go to the downloaded script path and run. (By default, it creates HADR with pacemaker cluster. )   
```
cd db2clusterconfig
./install.sh
```

For shared storage, give 'shared' option.      
```
./install.sh shared
```

If you have any doubt, see the terminal output how it looks like.   

[Terminal output:HADR pacemaker](screen_output.md)      
[Terminal output:Active standby shared storage with pacemaker](screen_output_shared.md)       

[contents](#contents)   

## Reference   

[Pacemaker versions shipped in Db2 version 11.5](https://www.ibm.com/docs/en/db2/11.5?topic=manager-supported-software-hardware-pacemaker)  

[Pacemaker active standby shared storage](https://www.ibm.com/docs/en/db2/11.5?topic=option-creating-pacemaker-managed-mutual-failover-db2-instance)     