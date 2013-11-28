#!/bin/bash

####################
#
# UDOO Config Main
#
####################

## Ettore Chimenti @ 2013/11


TITLE="UDOO Configuration Tool"

D="zenity"
PRINTENV="fw_printenv"
SETENV="fw_setenv"
NTPDATE="ntpdate-debian"
UDOO_USER="ubuntu"
MMC="/dev/mmcblk0"
PART="/dev/mmcblk0p1"

[[ -f /etc/udoo-config.conf ]] && . /etc/udoo-config.conf

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
  PASSWD=`$D --title="$TITLE" --entry --text="Enter new password" --hide-text`

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
  UDOO_NEW=`$D --title="$TITLE" --entry --text="Enter hostname (current: $UDOO_OLD)" `
  
  (( $? )) && exit 1
  
  UDOO_NEW=`echo $UDOO_NEW | tr -d " \t\n\r" `
  
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

  FBMEM=`echo $UDOO_ENV  | sed -n -e 's/.*fbmem\=\([0-9]*\)M.*/\1/p'`
  GPUMEM=`echo $UDOO_ENV | sed -n -e 's/.*gpu_reserved\=\([0-9]*\)M.*/\1/p'`

  (( $FBMEM )) || FBMEM=24
  (( $GPUMEM )) || GPUMEM=128

  FBMEM=`$D --title="$TITLE" \
		  --width=400 \
		  --height=300 \
		  --list \
		  --radiolist \
		  --hide-header \
		  --hide-column=2 \
		  --column="Checkbox" \
		  --column="Number" \
		  --column="Option" \
		  --text="Choose a memory value for framebuffer memory (current: ${FBMEM}M):" \
		  0 	6 	"6M" \
		  0 	10 	"10M" \
		  0 	24 	"24M" \
		  `
  (( $? )) && exit 1

  GPUMEM=`$D --title="$TITLE" \
		  --width=400 \
		  --height=300 \
		  --list \
		  --radiolist \
		  --hide-header \
		  --hide-column=2 \
		  --column="Checkbox" \
		  --column="Number" \
		  --column="Option" \
		  --text="Choose a memory value for video card reserved memory (current: ${GPUMEM}M):" \
		  0 	1 	"1M" \
		  0 	8 	"8M" \
		  0 	16 	"16M" \
		  0 	32 	"32M" \
		  0 	64 	"64M" \
		  0 	128 	"128M" \
		  0 	256 	"256M" \
		  `
  (( $? )) && exit 1 	 

  $SETENV memory "fbmem=${FBMEM}M gpu_reserved=${GPUMEM}M" || error

  sync

  ok "Success! (FBMEM=${FBMEM}M GPU_RESERVED=${GPUMEM}M)"
}

print_env()
{
  UDOO_ENV=`$PRINTENV 2>&1`

  (( $? )) && error "$UDOO_ENV"

  $PRINTENV 2>&1 | $D --width=400 --height=300 --title="$TITLE" --text-info --font="monospace,9"
}

ntpdate_rtc()
{
  NTP=`$NTPDATE 2>&1`
  case $? in
  0) 	;; 
  127) 	error "$NTPDATE not found!" ;;
  *) 	error "$( echo $NTP | sed -e 's/.*\]\: //')" ;;
  esac

  HWC=`hwclock -w 2>&1`
  (( $? )) && error $HWC
  
  ok "Success! (Time now is `date`)"
}

expand_fs()
{
  ( [[ -b $MMC ]] && [[ -b $PART ]] ) || error "I can't open $MMC / $PART . Check and edit /etc/udoo-config.conf"

  PARTSIZE=`parted $MMC -ms p | grep \^1 | cut -f 3 -d: `

  $D --question \
      --text="The root filesystem ($PARTSIZE) is going to be resized to SD card maximum available capacity.
This has the potential to cause loss of data. 
You are advised to backup your data before proceeding." || exit 1

  FIRSTSECT=`parted $MMC -ms unit s p | grep \^1 | cut -f 2 -d: | tr s \ `
  
  LASTSECT_PART=`parted $MMC -ms unit s p | grep \^1 | cut -f 3 -d: | tr s \ `
  LASTSECT_MMC=`parted $MMC -ms unit s p | grep $MMC | cut -f 2 -d: | tr s \ `
  
  [[ -f /etc/init.d/resize2fs_once ]] && error "You need to reboot. Now. I keep an eye on you."
  
  if (( $LASTSECT_PART == $LASTSECT_MMC - 1 )) 
  then
    $D --warning --text="The root filesystem ($PART - $PARTSIZE) is already resized to SD card maximum available capacity on the partition table. Trying to do a real resize."
    EXPAND=`resize2fs $PART`
    (( $? )) && error "$EXPAND"
    ok 
    exit 0
  fi  

  EXPAND=`fdisk $MMC <<FDISK
d
1
n
p
1
$FIRSTSECT

w
FDISK`

  EX=$?

  (( $EX )) && (( $EX != 1 )) && error "$EXPAND"

  # now set up an init.d script from https://github.com/asb/raspi-config
  cat <<EOF > /etc/init.d/resize2fs_once 
#!/bin/sh
### BEGIN INIT INFO
# Provides:          resize2fs_once
# Required-Start:
# Required-Stop:
# Default-Start: 2 3 4 5 S
# Default-Stop:
# Short-Description: Resize the root filesystem to fill partition
# Description:
### END INIT INFO

. /lib/lsb/init-functions

case "\$1" in
  start)
    log_daemon_msg "Starting resize2fs_once" &&
    resize2fs $PART &&
    rm /etc/init.d/resize2fs_once &&
    update-rc.d resize2fs_once remove &&
    log_end_msg \$?
    ;;
  *)
    echo "Usage: \$0 start" >&2
    exit 3
    ;;
esac
EOF

  chmod +x /etc/init.d/resize2fs_once 
  update-rc.d resize2fs_once defaults 
  
  PARTSIZE=`parted $MMC -ms p | grep \^1 | cut -f 3 -d: `

  ok "Root partition has been resized in the partition table ($PARTSIZE).\nThe filesystem will be enlarged upon the next reboot."
}

credits()
{
  $D 	--title="Credits" --info --text="
Credits by:

Ettore Chimenti AKA ektor-5

ek5.chimenti@gmail.com

for UDOO Team"
}

if [ $(id -u) -ne 0 ] 
then
  error "You're not root! Try execute: sudo udoo-config.sh" 
fi

until (( $EXIT ))
do
  CHOOSE=`$D --title="$TITLE" \
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
	  0		1		"Change User Password" \
	  0		2		"Change Hostname" \
	  0		3		"Service Management" \
	  0		4		"Change RAM memory layout" \
	  0		5		"Show u-boot Environment" \
	  0		6		"Update date from network and sync with RTC" \
	  0		7		"Expand root partition to disk maximum capacity" \
	  0		9		"Credits" \
	      `
  EXIT=$?
	      
  case $CHOOSE in

    1) (ch_passwd $UDOO_USER) ;;

    2) (ch_host) ;;

    3) (bum) ;;

    4) (mem_split) ;;

    5) (print_env) ;;
    
    6) (ntpdate_rtc) ;;

    7) (expand_fs) ;;

    9) (credits) ;;	
  esac

done
