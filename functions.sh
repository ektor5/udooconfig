#!/bin/bash

####################
#
# UDOO Config Main
#
####################

## Ettore Chimenti @ 2013/11


TITLE="UDOO Configuration Tool"

DIALOG="dialog"
XDIALOG="zenity"
PRINTENV="fw_printenv"
SETENV="fw_setenv"
NTPDATE="ntpdate-debian"

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
  $D --title="$TITLE" --error --text="$TEXT"
  exit 1
}

ok() {
  TEXT=$1
  [[ -z $TEXT ]] && TEXT="Success!"
  $D --title="$TITLE" --info --text="$TEXT"
}

ch_passwd()
{
  ## ch_passwd [user] 
  
  USER=$1  
  PASSWD=`$D --title="$TITLE" --entry --text="Enter password" --hide-text`

	(( $? )) && exit 1
 
  [[ -z $PASSWD ]] && error "Password cannot be empty"

  ## DOUBLE CHECK
  PASSWR=`$D --title="$TITLE" --entry --text="Re-enter password" --hide-text` 

  [[ $PASSWD != $PASSWR ]] && error 'Sorry, passwords do not match'
      
  echo $USER:$PASSWD | chpasswd || error

  ok
}

ch_host()
{
  UDOO_OLD=`cat /etc/hostname`
  UDOO_NEW=`$D --title="$TITLE" --entry --text="Enter hostname (current: $UDOO_OLD)" | tr -d " \t\n\r" `
  
  [[ -z $UDOO_NEW ]] && error "Hostname cannot be empty"
 
  xhost +
 
  if grep -q $UDOO_OLD /etc/hosts 
  then 
    sed -e "s/$UDOO_OLD/$UDOO_NEW/g" -i /etc/hosts 
  else
    echo "127.0.0.1 $UDOO_NEW" >> /etc/hosts
  fi
    
  echo $UDOO_NEW > /etc/hostname
  
  # CHECK

  [[ "$(cat /etc/hostname)" == 	"$UDOO_NEW" ]] && \
  [[ "$(cat /etc/hostname)" =~ 	"$UDOO_NEW" ]] || error

  ok "Success! (New hostname: $UDOO_NEW)
  Please reboot!"
}

mem_split()
{
	declare -i FBMEM GPUMEM

	UDOO_ENV=`$PRINTENV 2>&1`

	case $? in
		1)  	error "$UDOO_ENV" ;;
		127)	error "$PRINTENV not found" ;;
	esac

	FBMEM=`echo $UDOO_ENV | grep \^memory | sed -n -e 's/memory.*fbmem\=\([0-9]*\)M.*/\1/p'`
	GPUMEM=`echo $UDOO_ENV | grep \^memory | sed -n -e 's/memory.*gpumem\=\([0-9]*\)M.*/\1/p'`

	(( $FBMEM )) || FBMEM=24
	(( $GPUMEM )) || GPUMEM=128

	FBMEM=`$D --title="$TITLE" \
			--width=400 \
			--height=300 \
			--scale \
			--text="Choose a memory value for framebuffer (MB):" \
			--value=$FBMEM \
			--min-value=8 \
			--max-value=256 \
			`
	(( $? )) && exit 1

	GPUMEM=`$D --title="$TITLE" \
			--width=400 \
			--height=300 \
			--scale \
			--text="Choose a memory value for video card (MB):" \
			--value=$GPUMEM \
			--min-value=8 \
			--max-value=256 \
			`
	(( $? )) && exit 1 	 

	$SETENV memory fbmem=${FBMEM}M gpumem=${GPUMEM}M || error

	ok "Success! (FBMEM=${FBMEM}M GPUMEM=${GPUMEM}M)"
}

print_env()
{
	UDOO_ENV=`$PRINTENV 2>&1`

	(( $? )) && error "$UDOO_ENV"

	echo $UDOO_ENV | $D --title="$TITLE" --text-info
}

ntpdate_rtc()
{

	NTP=`$NTPDATE 2>&1`
	(( $? )) && echo $NTP && error "$( echo $NTP | sed -e 's/.*\]\: //')"

	HWC=`hwclock -w`
	(( $? )) && error $HWC

	ok "Success! (Time now is `date`)"

}

credits()
{
	$D 	--title="Credits" --info --text="
Credits by:

Ettore Chimenti AKA ektor-5

ek5.chimenti@gmail.com

for UDOO Team"
}
