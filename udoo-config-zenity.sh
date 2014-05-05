#!/bin/bash

####################
#
# UDOO Config zenity
#
####################

## Ettore Chimenti @ 2014/04

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
  ( (( $? )) || (( ! $FBMEM )) ) && exit 1
  

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
  ( (( $? )) || (( ! $GPUMEM )) ) && exit 1 	 

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

boot_default()
{
BOOT=`$PRINTENV src 2>&1`

(( $? )) && error "$BOOT"

BOOTSRC=`$D  --title="Default Boot Drive" \
	  --width=400 \
	  --height=300 \
	  --list \
	  --text="Choose a default boot drive. \
	  U-Boot will try first to boot up the system from there. (current: $BOOT )" \
	  --radiolist \
	  --hide-header \
	  --hide-column=2 \
	  --column="Checkbox" \
	  --column="Number" \
	  --column="Option" \
	  0		sata		"SATA Drive" \
	  0		mmc		"SD Card" \
	  0		net		"Network" \
	`
	
if [[ -n $BOOTSRC ]] 
  then 
  BOOT=`$SETENV src $BOOTSRC 2>&1`
  (( $? )) && error "$BOOT"
fi

ok "The default boot device is successfully changed"
}

boot_netvars()
{

IPADDR=`$PRINTENV ipaddr 2>&1`

(( $? )) && error "$IPADDR"

SERVERIP=`$PRINTENV serverip 2>&1`

(( $? )) && error "$SERVERIP"

NFSROOT=`$PRINTENV nfsroot 2>&1`

(( $? )) && error "$NFSROOT"

GET_CMD=`$PRINTENV get_cmd 2>&1`

(( $? )) && error "$GET_CMD"


FORM=`$D --forms --title="Set the environment values for netboot" \
	--text="Set the environment values for netboot"
	--add-entry="UDOO IP config (current: $IPADDR) [ip|dhcp]" \
	--add-entry="NTP Server IP (current: $SERVERIP)" \
	--add-entry="NTP File System Location (current: $NFSROOT)" \
	--add-list="uImage Retrival Method (current: $GET_CMD)" \
	--list-values="dhcp|tftp|ntp"   \
	`

IPADDR=`echo $FORM | cut -d \| -f 1`

[[ -z $IPADDR ]] && error "IPADDR cannot be empty"

SERVERIP=`echo $FORM | cut -d \| -f 2`

[[ -z $SERVERIP ]] && error "SERVERIP cannot be empty"

NFSROOT=`echo $FORM | cut -d \| -f 3`

[[ -z $NFSROOT ]] && error "NFSROOT cannot be empty"

GET_CMD=`echo $FORM | cut -d \| -f 4`

[[ -z $GET_CMD ]] && error "You have to specify a retrival method"


  BOOT=`$SETENV ipaddr $IPADDR 2>&1`
  (( $? )) && error "$BOOT"

  BOOT=`$SETENV serverip $SERVERIP 2>&1`
  (( $? )) && error "$BOOT"
  
  BOOT=`$SETENV nfsroot $NFSROOT 2>&1`
  (( $? )) && error "$BOOT"
  
  BOOT=`$SETENV get_cmd $GET_CMD 2>&1`
  (( $? )) && error "$BOOT"
  
  ok "The netboot environment variables has been changed successfully"
}

boot_mmcvars()
{

MMCPART=`$PRINTENV mmcpart 2>&1`

(( $? )) && error "$MMCPART"

MMCROOT=`$PRINTENV mmcroot 2>&1`

(( $? )) && error "$MMCROOT"


FORM=`$D --forms --title="Set the environment values for mmcboot" \
	--text="Set the environment values for mmcboot" \
	--add-entry="Partition Number (current: $MMCPART) [1-4]" \
	--add-entry="MMC Device Filename (current: $MMCROOT)" \
	`

MMCPART=`echo $FORM | cut -d \| -f 1`

[[ -z $MMCPART ]] && error "MMCPART cannot be empty"

MMCROOT=`echo $FORM | cut -d \| -f 2`

[[ -z $MMCROOT ]] && error "MMCROOT cannot be empty"


  BOOT=`$SETENV mmcpart $MMCPART 2>&1`
  (( $? )) && error "$BOOT"

  BOOT=`$SETENV mmcroot $MMCROOT 2>&1`
  (( $? )) && error "$BOOT"
 
  ok "The mmcboot environment variables has been changed successfully"
  
}

boot_satavars()
{

SATAPART=`$PRINTENV satapart 2>&1`

(( $? )) && error "$SATAPART"

SATAROOT=`$PRINTENV sataroot 2>&1`

(( $? )) && error "$SATAROOT"


FORM=`$D --forms --title="Set the environment values for sataboot" \
	--text="Set the environment values for sataboot" \
	--add-entry="Partition Number (current: $SATAPART) [1-4]" \
	--add-entry="SATA Device Filename (current: $SATAROOT)" \
	`

SATAPART=`echo $FORM | cut -d \| -f 1`

[[ -z $SATAPART ]] && error "SATAPART cannot be empty"

SATAROOT=`echo $FORM | cut -d \| -f 2`

[[ -z $SATAROOT ]] && error "SATAROOT cannot be empty"


  BOOT=`$SETENV satapart $SATAPART 2>&1`
  (( $? )) && error "$BOOT"

  BOOT=`$SETENV sataroot $SATAROOT 2>&1`
  (( $? )) && error "$BOOT"
 
  ok "The sataboot environment variables has been changed successfully"
  
}

boot_script()
{
BOOT=`$PRINTENV src 2>&1`

(( $? )) && error "$BOOT"

SCRIPT=`$PRINTENV script 2>&1`

(( $? )) && error "$SCRIPT"


FORM=`$D --forms --title="Set the boot script" \
	--text="Set the boot script variables that will be executed on the root of the default boot device (current: $BOOT)" \
	--add-entry="Script Filename (current: $SCRIPT)" \
	`

SCRIPT=`echo $FORM`

[[ -z $SCRIPT ]] && error "SCRIPT cannot be empty"

BOOT=`$SETENV script $SCRIPT 2>&1`
  (( $? )) && error "$BOOT"
 
SCRIPT=`$PRINTENV script 2>&1`

(( $? )) && error "$SCRIPT"
 
  ok "The boot script variable has been changed successfully (now: $SCRIPT)"

}

boot_video()
{

VIDEO=`$PRINTENV video 2>&1`

(( $? )) && error "$VIDEO"

VIDEO_DEV=`echo $VIDEO | cut -d "=" -f 3- | cut -d "," -f 1`  # e.g. video=mxcfb0:dev=hdmi,1920x1080M@60,bpp=32
VIDEO_RES=`echo $VIDEO | cut -d "=" -f 3- | cut -d "," -f 2-`  # e.g. video=mxcfb0:dev=hdmi,1920x1080M@60,bpp=32

FORM=`$D --forms --title="Set the video output environment variables" \
	--text="Set the video output environment variables" \
	--add-list="Default video device (current: $VIDEO_DEV)" \
	--list-values="hdmi|lvds" \
	--add-list="Default resolution for video device" \
	--list-values="1024x768@60,bpp=32|1366x768@60,bpp=32|1920x1080M@60,bpp=32" \
	`

VIDEO_DEV=`echo $FORM | cut -d "|" -f 1` 

[[ -z $VIDEO_DEV ]] && error "VIDEO_DEV cannot be empty"

VIDEO_RES=`echo $FORM | cut -d "|" -f 2` 

[[ -z $VIDEO_RES ]] && error "VIDEO_RES cannot be empty"

VIDEO=`$SETENV video "video=mxcfb0:dev=$VIDEO_DEV,$VIDEO_RES" 2>&1`
  (( $? )) && error "$VIDEO"

VIDEO=`$PRINTENV video 2>&1`

(( $? )) && error "$VIDEO"
  
ok "The boot video variable has been changed successfully (now: $VIDEO)"
}

boot_mgr()
{
until (( $EXIT ))
do
  CHOOSE=`$D  --title="U-Boot Manager" \
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
	  0		1		"Set default boot device" \
	  0		2		"Set boot variables for netboot" \
	  0		3		"Set boot variables for mmcboot" \
	  0		4		"Set boot variables for sataboot" \
	  0		5		"Use boot script" \
	  0		6		"Set default video output" \
	  0		7		"Change RAM memory layout" \
	  0		9		"Show U-Boot Environment" \
	`  
  EXIT=$?
  
  case $CHOOSE in

    1) (boot_default) ;;

    2) (boot_netvars) ;;
    
    3) (boot_mmcvars) ;;
    
    4) (boot_satavars) ;;

    5) (boot_script) ;;

    6) (boot_video) ;;
    
    7) (mem_split) ;;
   
    9) (print_env) ;;
    
  esac

done
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
	  0		3		"Service Management" \
	  0		4		"U-Boot Manager" \
	  0		1		"Change User Password" \
	  0		2		"Change Hostname" \
	  0		6		"Update date from network and sync with RTC" \
	  0		7		"Expand root partition to disk max capacity" \
	  0		9		"Credits" \
	      `
  EXIT=$?
  
  case $CHOOSE in

    1) (ch_passwd $UDOO_USER) ;;

    2) (ch_host) ;;

    3) (bum) ;;
    
    4) (boot_mgr) ;;    
    
    6) (ntpdate_rtc) ;;

    7) (expand_fs) ;;

    9) (credits) ;;

  esac

done
