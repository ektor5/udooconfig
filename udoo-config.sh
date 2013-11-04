#!/bin/bash

####################
#
# UDOO Config Functions
#
####################

## Ettore Chimenti @ 2013/11

. functions.sh

if [ $(id -u) -ne 0 ] 
then
 error "You're not root! Try execute: sudo udoo-config.sh" 
fi

until (( $EXIT ))
do
  CHOOSE=`$D \
	  --width=400 \
	  --height=300 \
	  --list \
	  --text="Choose an option:" \
	  --radiolist \
	  --hide-header \
	  --hide-column=2 \
	  --column="Checkbox" \
	  --column="Number" \
	  --column="Option" \
	  0	1	"Change User Password" \
	  0	2	"Change Hostname" \
	  0	3	"Service Management" \
	  0	4	"Memory Split" \
	  0	5	"Show u-boot Environment" \
	      `
  EXIT=$?
	      
  case $CHOOSE in

    1) (ch_passwd $UDOO_USER) ;;

    2) (ch_host) ;;

    3) (bum) ;;

    4) (mem_split) ;;

    5) ( fw_printenv | zenity --text-info) ;;

  esac

done
 



