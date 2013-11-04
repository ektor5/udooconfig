#!/bin/bash

####################
#
# UDOO Config Main
#
####################

## Ettore Chimenti @ 2013/11


TITLE="udoo-config"
DIALOG="dialog"
XDIALOG="zenity --title=$TITLE"

UDOO_USER="ubuntu"

if ( [[ $1 == "-n"  ]] || [[ -z $DISPLAY ]] )
then
  D=$DIALOG
 else
  D=$XDIALOG
fi

error() {
  TEXT=$1
  [[ -z $TEXT ]] && TEXT="An error has occoured!"
  $D --error --text="$TEXT"
  exit 1
}

ok() {
  TEXT=$1
  [[ -z $TEXT ]] && TEXT="Success!"
  $D --info --text="$TEXT"
}

ch_passwd()
{
  ## ch_passwd [user] 
  
  USER=$1  
  PASSWD=`$D --entry --text="Enter password" --hide-text`

  [[ -z $PASSWD ]] && error

  ## DOUBLE CHECK
  PASSWR=`$D --entry --text="Re-enter password" --hide-text` 

  [[ $PASSWD != $PASSWR ]] && error 'Sorry, passwords do not match'
      
  echo $USER:$PASSWD | chpasswd || error

  ok
}

ch_host()
{
  ## ch_host 
  UDOO_OLD=`cat /etc/hostname`
  UDOO_NEW=`$D --entry --text="Enter hostname (current: $UDOO_OLD)" | tr -d " \t\n\r" `
  [ $? != 0 ] || exit 1
  
  [[ -z $UDOO_NEW ]] && error 
 
  echo $UDOO_NEW > /etc/hostname
  sed -e "s/$UDOO_OLD/$UDOO_NEW/g" -i /etc/hosts 
  
  # CHECK
  [[ "$(cat /etc/hostname)" != 	"$UDOO_NEW" ]] || error
  
  ok 
}

mem_split()
{
declare -i FBMEM GPUMEM

FBMEM=`fw_printenv | grep \^memory | sed -n -e 's/memory.*fbmem\=\([0-9]*\)M.*/\1/p'`
GPUMEM=`fw_printenv | grep \^memory | sed -n -e 's/memory.*gpumem\=\([0-9]*\)M.*/\1/p'`

(( $FBMEM )) || FBMEM=24
(( $GPUMEM )) || GPUMEM=128

 FBMEM=`$D \
	  --width=400 \
	  --height=300 \
	  --scale \
	  --text="Choose a memory value for framebuffer (MB):" \
	  --value=$FBMEM \
	  --min-value=8 \
	  --max-value=256 \
	  `
(( $? )) && exit 1
	
 GPUMEM=`$D \
	  --width=400 \
	  --height=300 \
	  --scale \
	  --text="Choose a memory value for video card (MB):" \
	  --value=$GPUMEM \
	  --min-value=8 \
	  --max-value=256 \
	  `
(( $? )) && exit 1 	 

fw_setenv memory fbmem=${FBMEM}M gpumem=${GPUMEM}M || error

ok
}
