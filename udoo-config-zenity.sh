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

[[ -f /etc/udoo-config.conf ]] && . /etc/udoo-config.conf

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/udoo-functions.sh

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

zch_passwd()
{
  ## ch_passwd 
  
  local PASSWD
  PASSWD=`$D --title="$TITLE" --entry --text="Enter new password" --hide-text`

  (( $? )) && exit 1
 
  [[ -z $PASSWD ]] && error "Password cannot be empty"

  ## DOUBLE CHECK
  PASSWR=`$D --title="$TITLE" --entry --text="Re-enter password" --hide-text` 

  [[ $PASSWD != $PASSWR ]] && error 'Sorry, passwords do not match'
      
  ch_passwd $UDOO_USER $PASSWD
      
  ok
}

zch_host()
{
  local UDOO_OLD=`cat /etc/hostname`
  local UDOO_NEW
  UDOO_NEW=`$D --title="$TITLE" --entry --text="Enter hostname (current: $UDOO_OLD)" `
  
  (( $? )) && exit 1
  
  UDOO_NEW=`echo $UDOO_NEW | tr -d " \t\n\r" `
  
  [[ -z $UDOO_NEW ]] && error "Hostname cannot be empty"
 
  xhost +
 
  ch_host $UDOO_NEW || error

  ok "Success! (New hostname: $UDOO_NEW)
Please reboot!"
}

zmem_split()
{
  local UDOO_ENV
  local FBMEM
  local GPUMEM
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

  mem_split $FBMEM $GPUMEM || error

  sync

  ok "Success! (FBMEM=${FBMEM}M GPU_RESERVED=${GPUMEM}M)"
}

zprint_env()
{
  print_env | $D --width=400 --height=300 --title="$TITLE" --text-info --font="monospace,9"
}

zntpdate_rtc()
{
  ntpdate_rtc || error
  ok "Success! (Time now is `date`)"
}

zch_keyboard(){
#local UDOO_OLD=`grep XKBLAYOUT $KBD_DEFAULT | cut -d = -f 2 | tr -d \"`
local UDOO_OLD=`setxkbmap -query | sed -e 's/^layout:\ *\(\w*\)/\1/p' -n`
local UDOO_NEW

take_locales(){
#take_locales($current) 
#parser
local flag=false
local line
local current=$1

while read line
#read RULES lines
do  
  #check flag
  if [[ $flag != "true" ]]
    then
      #trash every line until !layout comes
      [[ $line =~ '! layout' ]] && \
      flag=true
    else 
      #end reading 
      [[ $line == '' ]] && return
      #process line
      line=`echo $line | sed -e 's/ \s*/ \"/' -e 's/$/\" /'`
      #if line is current layout say TRUE
      if [[ $line =~ ^$current ]]
	then echo TRUE $line
	else echo FALSE $line
      fi
  fi 
done < <(cat $KBD_RULES)
#named pipe
}

UDOO_NEW=`take_locales $UDOO_OLD | xargs \
	     $D --title="$TITLE" --list \
	     --text="Enter new keyboard locale" \
	     --width=400 \
	     --height=300 \
	     --radiolist \
	     --hide-header \
	     --print-column=2 \
	     --hide-column=2 \
	     --column="Checkbox" \
	     --column="Keycode" \
	     --column="Locale" \
	     `
  
(( $? )) && exit 1

[[ $UDOO_NEW == $UDOO_OLD ]] && exit 1

#UDOO_NEW=`echo $UDOO_NEW | tr -d " \t\n\r" `

[[ -z $UDOO_NEW ]] && error "LOCALE cannot be empty"

ch_keyboard $UDOO_NEW || error 

UDOO_NEW=`grep XKBLAYOUT $KBD_DEFAULT | cut -d= -f2 | tr -d \"`

ok "Locale has changed! (current: $UDOO_NEW)"

}

zch_timezone(){

local LOCALE
local UDOO_OLD=`readlink $ZONEFILE | cut -d/ -f5-`
local UDOO_NEW
UDOO_NEW=`$D --title="$TITLE" --entry --text="Enter new timezone (e.g. Europe/Rome)  (current: $UDOO_OLD)" `

(( $? )) && exit 1

UDOO_NEW=`echo $UDOO_NEW | tr -d " \t\n\r" `

[[ -z $UDOO_NEW ]] && error "LOCALE cannot be empty"

ch_timezone $UDOO_NEW || error 

UDOO_NEW=`readlink $ZONEFILE | cut -d/ -f5-`

ok "Timezone has changed! (current: $UDOO_NEW)"

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

zboot_default()
{
local BOOTSRC
local BOOT

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
(( $? )) && exit 1
if [[ -n $BOOTSRC ]] 
  then 
    boot_default $BOOTSRC || error
  else 
    exit 
fi

BOOT=`$PRINTENV src 2>&1`

ok "The default boot device is successfully changed (current: $BOOT)"
}

zboot_netvars()
{
local IPADDR
local SERVERIP
local NFSROOT
local GET_CMD
local BOOT

IPADDR=`$PRINTENV ipaddr 2>&1`

(( $? )) && error "$IPADDR"

SERVERIP=`$PRINTENV serverip 2>&1`

(( $? )) && error "$SERVERIP"

NFSROOT=`$PRINTENV nfsroot 2>&1`

(( $? )) && error "$NFSROOT"

GET_CMD=`$PRINTENV get_cmd 2>&1`

(( $? )) && error "$GET_CMD"


FORM=`$D --forms --title="Set the environment values for netboot" \
	--text="Set the environment values for netboot" \
	--add-entry="UDOO IP config (current: $IPADDR) [ip|dhcp]" \
	--add-entry="NTP Server IP (current: $SERVERIP)" \
	--add-entry="NTP File System Location (current: $NFSROOT)" 
`

(( $? )) && exit 1
IPADDR=`echo $FORM | cut -d \| -f 1`

[[ -z $IPADDR ]] && error "IPADDR cannot be empty"

SERVERIP=`echo $FORM | cut -d \| -f 2`

[[ -z $SERVERIP ]] && error "SERVERIP cannot be empty"

NFSROOT=`echo $FORM | cut -d \| -f 3`

[[ -z $NFSROOT ]] && error "NFSROOT cannot be empty"

GET_CMD=`$D --title="$TITLE" \
	--text="uImage Retrival Method (current: $GET_CMD)" \
	--width=400 \
	--height=300 \
	--list \
	--radiolist \
	--hide-header \
	--print-column="ALL" \
	--column="Checkbox" \
	--column="Method" \
	0 "dhcp" \
	0 "tftp" \
	0 "ntp"  \
	`
(( $? )) && exit 1

[[ -z $GET_CMD ]] && error "You have to specify a retrival method"

boot_netvars $IPADDR $SERVERIP $NFSROOT $GET_CMD || error 
  
ok "The netboot environment variables has been changed successfully"

}

zboot_mmcvars()
{

local MMCPART
local MMCROOT
local FORM

MMCPART=`$PRINTENV mmcpart 2>&1`

(( $? )) && error "$MMCPART"

MMCROOT=`$PRINTENV mmcroot 2>&1`

(( $? )) && error "$MMCROOT"

FORM=`$D --forms --title="Set the environment values for mmcboot" \
	--text="Set the environment values for mmcboot" \
	--add-entry="Partition Number (current: $MMCPART) [1-4]" \
	--add-entry="MMC Device Filename (current: $MMCROOT)" \
	`
(( $? )) && exit 1
MMCPART=`echo $FORM | cut -d \| -f 1`

[[ -z $MMCPART ]] && error "MMCPART cannot be empty"

MMCROOT=`echo $FORM | cut -d \| -f 2`

[[ -z $MMCROOT ]] && error "MMCROOT cannot be empty"

boot_mmcvars $MMCPART $MMCROOT || error
 
ok "The mmcboot environment variables has been changed successfully"
  
}

zboot_satavars()
{

local SATAPART
local SATAROOT
local FORM

SATAPART=`$PRINTENV satapart 2>&1`

(( $? )) && error "$SATAPART"

SATAROOT=`$PRINTENV sataroot 2>&1`

(( $? )) && error "$SATAROOT"


FORM=`$D --forms --title="Set the environment values for sataboot" \
	--text="Set the environment values for sataboot" \
	--add-entry="Partition Number (current: $SATAPART) [1-4]" \
	--add-entry="SATA Device Filename (current: $SATAROOT)" \
	`
(( $? )) && exit 1
SATAPART=`echo $FORM | cut -d \| -f 1`

[[ -z $SATAPART ]] && error "SATAPART cannot be empty"

SATAROOT=`echo $FORM | cut -d \| -f 2`

[[ -z $SATAROOT ]] && error "SATAROOT cannot be empty"


boot_satavars $SATAPART $SATAROOT || error
 
ok "The sataboot environment variables has been changed successfully"
  
}

zboot_script()
{
local BOOT
local SCRIPT
local FORM

BOOT=`$PRINTENV src 2>&1`

(( $? )) && error "$BOOT"

SCRIPT=`$PRINTENV script 2>&1`

(( $? )) && error "$SCRIPT"


FORM=`$D --forms --title="Set the boot script" \
	--text="Set the boot script variables that will be executed on the root of the default boot device (current: $BOOT)" \
	--add-entry="Script Filename (current: $SCRIPT)" \
	`
(( $? )) && exit 1
SCRIPT=`echo $FORM`

[[ -z $SCRIPT ]] && error "SCRIPT cannot be empty"

boot_script $SCRIPT || error
 
  ok "The boot script variable has been changed successfully (now: $SCRIPT)"

}

zboot_video()
{
local VIDEO_DEV
local VIDEO_RES
local VIDEO

VIDEO=`$PRINTENV video 2>&1`

(( $? )) && error "$VIDEO"

VIDEO_DEV=`echo $VIDEO | cut -d "=" -f 3- | cut -d "," -f 1`  # e.g. video=mxcfb0:dev=hdmi,1920x1080M@60,bpp=32
VIDEO_RES=`echo $VIDEO | cut -d "=" -f 3- | cut -d "," -f 2-`  # e.g. video=mxcfb0:dev=hdmi,1920x1080M@60,bpp=32

#zenity segfaults, turn back to --list

# FORM=`$D --forms --title="Set the video output environment variables" \
# 	--text="Set the video output environment variables" \
# 	--add-list="Default video device (current: $VIDEO_DEV)" \
# 	--list-values="hdmi|lvds" \
# 	--add-list="Default resolution for video device" \
# 	--list-values="1024x768@60,bpp=32|1366x768@60,bpp=32|1920x1080M@60,bpp=32" \
# 	`
#VIDEO_DEV=`echo $FORM | cut -d "|" -f 1` 
#VIDEO_RES=`echo $FORM | cut -d "|" -f 2` 

VIDEO_DEV=`$D --list --title="Set the video output environment variables" \
		  --radiolist \
		  --hide-header \
		  --hide-column=2 \
		  --column="Checkbox" \
		  --column="Option" \
		  --column="Video" \
		  --text="Default video device (current: $VIDEO_DEV)" \
		  0	"hdmi" 	 "HDMI" \
		  0	"ldb1" 	 "LVDS 7\"" \
		  0	"ldb2" 	 "LVDS 15\"" \
`

(( $? )) && exit 1

[[ -z $VIDEO_DEV ]] && error "VIDEO_DEV cannot be empty"

case $VIDEO_DEV in 
  hdmi) VIDEO_RES=`$D --list --title="Set the video output environment variables" \
	    --radiolist \
	    --hide-header \
	    --column="Checkbox" \
	    --column="Option" \
	    --text="Default resolution for video device" \
	  0 	"1024x768@60,bpp=32" \
	  0 	"1366x768@60,bpp=32" \
	  0 	"1920x1080M@60,bpp=32" \
	`
	(( $? )) && exit 1
	;;
  
  ldb1) VIDEO_RES="LDB-WVGA,if=RGB666,bpp=32" ;;
  ldb2) VIDEO_RES="1366x768M@60,if=RGB24,bpp=32" ;;

esac 
 
[[ -z $VIDEO_RES ]] && error "VIDEO_RES cannot be empty"

boot_video $VIDEO_DEV $VIDEO_RES || error
  
ok "The boot video variable has been changed successfully (now: $VIDEO)"
}

zboot_reset(){
#boot_reset()

  $D --question \
      --text="The u-boot environment stored in your SD is going to be erased and overwritten by this configurator's default values. 
You are advised to backup your actual environment before proceeding." || exit 1

boot_reset || error

ok "The u-boot environment has been resetted successfully"

}

zboot_mgr()
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
	  0		8		"Reset U-Boot Environment" \
	  0		9		"Show U-Boot Environment" \
	`  
  EXIT=$?
  
  case $CHOOSE in

    1) (zboot_default) ;;

    2) (zboot_netvars) ;;
    
    3) (zboot_mmcvars) ;;
    
    4) (zboot_satavars) ;;

    5) (zboot_script) ;;

    6) (zboot_video) ;;
    
    7) (zmem_split) ;;
    
    8) (zboot_reset) ;;
   
    9) (zprint_env) ;;
    
  esac

done
}

zsys_mgr()
{
until (( $EXIT ))
do
  CHOOSE=`$D  --title="System Manager" \
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
	  0		3		"Change Keyboard Layout" \
	  0		4		"Change Timezone Setting" \
	  0		5		"Change VNC Password" \
	  0		6		"Update date from network and sync with RTC" \
	  0		7		"Expand root partition to disk max capacity" 
	`  
  EXIT=$?
  
  case $CHOOSE in

    1) (zch_passwd $UDOO_USER) ;;

    2) (zch_host) ;;
    
    3) (zch_keyboard) ;;

    4) (zch_timezone) ;;
    
    5) (zch_vncpasswd) ;;
     
    6) (zntpdate_rtc) ;;
    
    7) (expand_fs) ;;       
  esac

done
}

zcredits()
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
	  0		1		"System Manager" \
	  0		2		"U-Boot Manager" \
	  0		9		"Credits" \
	      `
  EXIT=$?
  
  case $CHOOSE in

    1) (zsys_mgr) ;;

    2) (zboot_mgr) ;;   

    9) (zcredits) ;;

  esac

done
