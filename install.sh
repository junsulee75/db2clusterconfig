#!/bin/bash

./0_osenv.sh
./setup.sh $1  # If no parameter, HADR / pacemaker by default . 'shared' : active/standby shared with pacemaker

