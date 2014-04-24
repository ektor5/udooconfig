#!/bin/bash

####################
#
# UDOO Config Functions
#
####################

## Ettore Chimenti @ 2014/04

error() {
  #error($E_TEXT,$E_CODE)

  local E_TEXT=$1
  local E_CODE=$2
  
  [[ -z $E_CODE ]] && E_CODE=1
  [[ -z $E_TEXT ]] || echo $E_TEXT
  exit $E_CODE
}

ok() {
  #ok($OK_TEXT)
  local OK_TEXT=$1
  [[ -z $OK_TEXT ]] && OK_TEXT="Success!!"
  [[ -z $OK_TEXT ]] || echo $OK_TEXT 
  exit 0
}

ch_passwd() {
  ## ch_passwd($user, $passwd)
  
  local USER=$1  
  local PASSWD=$2
 
  [[ -z $USER ]] && error "User cannot be empty"
  [[ -z $(grep -P "^$USER:" /etc/passwd) ]]  && error "User not found in /etc/passwd"
  [[ -z $PASSWD ]] && error "Password cannot be empty"

  echo $USER:$PASSWD | chpasswd || error "chpasswd failed"

  ok
}

ch_host() {
  #ch_host($UDOO_NEW)
  local UDOO_OLD=`cat /etc/hostname`
  UDOO_NEW=$1
  local UDOO_NEW=`echo $UDOO_NEW | tr -d " \t\n\r" `

  if grep -q " $UDOO_OLD\$" /etc/hosts 
  then 
    sed -e "s/$UDOO_OLD/$UDOO_NEW/g" -i /etc/hosts 
  else
    echo "\n127.0.0.1 $UDOO_NEW" >> /etc/hosts
  fi
    
  echo $UDOO_NEW > /etc/hostname
  
  # CHECK

  [[ "$(cat /etc/hostname)" == 	"$UDOO_NEW" ]] && \
  [[ "$(cat /etc/hostname)" =~ 	"$UDOO_NEW" ]] || error

  ok "Success! (New hostname: $UDOO_NEW)
Please reboot!"
}

mem_split() {  
#mem_split($FBMEM $GPUMEM)
  local FBMEM
  local GPUMEM
  declare -i FBMEM GPUMEM
  
  FBMEM=$1
  GPUMEM=$2
  
  local UDOO_ENV
  UDOO_ENV=`$PRINTENV 2>&1`

  case $? in
	  1)  	error "$UDOO_ENV" ;;
	  127)	error "$PRINTENV not found" ;;
  esac

  FBMEM=`echo $UDOO_ENV  | sed -n -e 's/.*fbmem\=\([0-9]*\)M.*/\1/p'`
  GPUMEM=`echo $UDOO_ENV | sed -n -e 's/.*gpu_reserved\=\([0-9]*\)M.*/\1/p'`

  (( $FBMEM )) || FBMEM=24
  (( $GPUMEM )) || GPUMEM=128

  $SETENV memory "fbmem=${FBMEM}M gpu_reserved=${GPUMEM}M" || error

  sync

  ok "Success! (FBMEM=${FBMEM}M GPU_RESERVED=${GPUMEM}M)"
}

print_env() {
  local UDOO_ENV
  UDOO_ENV=`$PRINTENV 2>&1`

  (( $? )) && error "$UDOO_ENV"

  $PRINTENV 2>&1 
}

ntpdate_rtc() {
  local NTP
  NTP=`$NTPDATE 2>&1`
  case $? in
    0) 	;; 
  127) 	error "$NTPDATE not found!" ;;
    *) 	error "$( echo $NTP | sed -e 's/.*\]\: //')" ;;
  esac

  local HWC
  HWC=`hwclock -w 2>&1`
  (( $? )) && error $HWC
  
  ok "Success! (Time now is `date`)"
}

expand_fs() {
  ( [[ -b $MMC ]] && [[ -b $PART ]] ) || error "I can't open $MMC / $PART . Check and edit /etc/udoo-config.conf"

  local PARTSIZE=`parted $MMC -ms p | grep \^1 | cut -f 3 -d: `

  local FIRSTSECT=`parted $MMC -ms unit s p | grep \^1 | cut -f 2 -d: | tr s \ `
  
  local LASTSECT_PART=`parted $MMC -ms unit s p | grep \^1 | cut -f 3 -d: | tr s \ `
  local LASTSECT_MMC=`parted $MMC -ms unit s p | grep $MMC | cut -f 2 -d: | tr s \ `
  
  [[ -f /etc/init.d/resize2fs_once ]] && error "You need to reboot. Now. I keep an eye on you." 2
  
  if (( $LASTSECT_PART == $LASTSECT_MMC - 1 )) 
  then
    local EXPAND
    EXPAND=`resize2fs $PART`
    (( $? )) && error "$EXPAND"
    ok 
    exit 0
  fi  
  local EXPAND
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
  
  local PARTSIZE=`parted $MMC -ms p | grep \^1 | cut -f 3 -d: `

  ok "Root partition has been resized in the partition table ($PARTSIZE).\nThe filesystem will be enlarged upon the next reboot."
}

boot_default() {
#boot_default($BOOTSRC)
local BOOTSRC=$1
local BOOT

BOOT=`$PRINTENV src 2>&1`

(( $? )) && error "$BOOT"

if [[ -n $BOOTSRC ]] 
  then 
  BOOT=`$SETENV src $BOOTSRC 2>&1`
  (( $? )) && error "$BOOT"
fi

ok "The default boot device is successfully changed"
}

boot_netvars() {
#boot_netvars($IPADDR, $SERVERIP, $NFSROOT, $GET_CMD)

local IPADDR=$1
local SERVERIP=$2
local NFSROOT=$3
local GET_CMD=$4
local BOOT


[[ -z $IPADDR ]] && error "IPADDR cannot be empty"

[[ -z $SERVERIP ]] && error "SERVERIP cannot be empty"

[[ -z $NFSROOT ]] && error "NFSROOT cannot be empty"

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

boot_mmcvars() {
#boot_mmcvars($MMCPART, $MMCROOT)

local MMCPART=$1
local MMCROOT=$2
local BOOT

[[ -z $MMCPART ]] && error "MMCPART cannot be empty"

[[ -z $MMCROOT ]] && error "MMCROOT cannot be empty"

  BOOT=`$SETENV mmcpart $MMCPART 2>&1`
  (( $? )) && error "$BOOT"

  BOOT=`$SETENV mmcroot $MMCROOT 2>&1`
  (( $? )) && error "$BOOT"
 
  ok "The mmcboot environment variables has been changed successfully"
  
}

boot_satavars() {
#boot_mmcvars($SATAPART, $SATAROOT)

local SATAPART=$1
local SATAPART=$2
local BOOT

[[ -z $SATAPART ]] && error "SATAPART cannot be empty"

[[ -z $SATAROOT ]] && error "SATAROOT cannot be empty"

  BOOT=`$SETENV satapart $SATAPART 2>&1`
  (( $? )) && error "$BOOT"

  BOOT=`$SETENV sataroot $SATAROOT 2>&1`
  (( $? )) && error "$BOOT"
 
  ok "The sataboot environment variables has been changed successfully"
  
}

boot_script() {
#boot_script($SCRIPT)
local BOOT
local SCRIPT=$1

[[ -z $SCRIPT ]] && error "SCRIPT cannot be empty"

BOOT=`$SETENV script $SCRIPT 2>&1`
  (( $? )) && error "$BOOT"
 
SCRIPT=`$PRINTENV script 2>&1`

(( $? )) && error "$SCRIPT"
 
  ok "The boot script variable has been changed successfully (now: $SCRIPT)"

}

boot_video() {
#boot_video($VIDEO_DEV,$VIDEO_RES)
local VIDEO_DEV
local VIDEO_RES
local VIDEO

[[ -z $VIDEO_DEV ]] && error "VIDEO_DEV cannot be empty"

[[ -z $VIDEO_RES ]] && error "VIDEO_RES cannot be empty"

VIDEO=`$SETENV video "video=mxcfb0:dev=$VIDEO_DEV,$VIDEO_RES" 2>&1`
(( $? )) && error "$VIDEO"

VIDEO=`$PRINTENV video 2>&1`
(( $? )) && error "$VIDEO"
  
ok "The boot video variable has been changed successfully (now: $VIDEO)"
}

ch_locale(){
#ch_locale($LOCALE)
local LOCALE=$1

[[ -z $LOCALE ]] && error "LOCALE cannot be empty"
#Search in /usr/share/X11/xkb/rules/xorg.lst
[[ -z `grep -qc " $LOCALE " $KBD_RULES` ]] && error "LOCALE not valid (not in $KBD_RULES)"

#Search for /etc/default/keyboard
[[ -f $KBD_DEFAULT ]] && error "$KBD_DEFAULT not found"

if [[ -z `grep -qc XKBLAYOUT $KBD_DEFAULT` ]]
  then
    sed -n -e "s/XKBLAYOUT=.*/XKBLAYOUT=\"$LOCALE\"/" -i $KBD_DEFAULT
  else
    echo XKBLAYOUT=\"$LOCALE\" >> $KBD_DEFAULT
fi

setxkbmap $LOCALE

local E_CODE=$?

(( $? )) && error "Cannot set keyboard mapping directly"

ok

}

credits() {

cat <<CREDITS
Credits by:

Ettore Chimenti AKA ektor-5

ek5.chimenti@gmail.com

for UDOO Team
CREDITS
}

usage(){
cat <<USAGE
TODO

USAGE
}