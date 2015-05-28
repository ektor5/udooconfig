#!/bin/bash

####################
#
# UDOO Config Functions
#
####################

## Ettore Chimenti @ 2015/05

if [[ $0 =~ "functions" ]] 
then
  echo You cannot execute this script directly
  exit 1
fi

PRINTENV="fw_printenv"
SETENV="fw_setenv"
NTPDATE="ntpdate-debian"
CHKCONF="chkconfig"
UDOO_USER="ubuntu"
SATADRIVES="/dev/disk/by-id/ata-"
SATADEV="/dev/sda"
MMC="/dev/mmcblk0"
PART="/dev/mmcblk0p1"
SRCFILE="$DIR/udoo-defaultenv.src"
INSSERV="/usr/lib/insserv/insserv"
VNCPASSWD="/home/$UDOO_USER/.vnc/passwd"

ZONETIME="/etc/timezone"
ZONEFILE="/etc/localtime"
ZONEINFO="/usr/share/zoneinfo/"
declare -a ZONECONTINENTS
ZONECONTINENTS=('America' 'Asia' 'Europe' 'Australia' 'Africa' 'Atlantic' 'Pacific' 'Antarctica' 'Etc')

KBD_DEFAULT="/etc/default/keyboard"
KBD_RULES="/usr/share/X11/xkb/rules/xorg.lst"

declare -a DAEMON_LIST
DAEMON_LIST=( ssh openvnc ntp )

CAMERA_NOT_RUN="/etc/camera/camera_not_to_be_run"
CAMERA_DIR="/etc/camera/"
CAMERA="camera"

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

daemonctl(){
#daemonctl($DAEMON,$OPT)

  #check if insserv is where it should be, if not, symlink it
  [[ -f /sbin/insserv ]] || [[ -f $INSSERV ]] && ln -sf $INSSERV /sbin/insserv

  (( $? )) && error "Failed to symlink $INSSERV to /sbin/insserv"

  local DAEMON=$1
  local OPT=$2

  #filter
  case $OPT in
    on)		SELECT=on  ;; 
    off) 	SELECT=off ;; 
    *)    	SELECT="" ;;
  esac

  if [[ -z $DAEMON ]] 
  then
    #LIST ALL
    $CHKCONF 2>/dev/null  
  else
    #DO SOMETHING
    #echo $CHKCONF $DAEMON $SELECT 1>&2 #DEBUG
    $CHKCONF $DAEMON $SELECT 2>/dev/null
    E_CODE=$?
    (( $E_CODE )) && error "Cannot install/remove service $DAEMON"

  fi 
    
  [[ -z $OPT ]] && QUIET=1
  
  ok "All tasks completed successfully"

}

ch_vncpasswd(){
#ch_vncpasswd($PASSWD)
  local PASSWD=$1

  [[ -z $PASSWD ]] && error "Password cannot be empty!"

  #Write it into /home/user/.vnc/passwd
  echo $PASSWD | vncpasswd -f > $VNCPASSWD
   
  (( $? )) && error "Failed to change the password"
    
  ok "The password has been changed successfully!"

}

ch_passwd() {
#ch_passwd($user, $passwd)
  
  local USER=$1  
  local PASSWD=$2
 
  [[ -z $USER ]] && error "User cannot be empty"
  [[ -z $(grep -P "^$USER:" /etc/passwd) ]]  && error "User not found in /etc/passwd"
  [[ -z $PASSWD ]] && error "Password cannot be empty"

  echo $USER:$PASSWD | chpasswd || error "Failed to change the password"

  ok "The password has been changed successfully!"
}

ch_host() {
#ch_host($UDOO_NEW)
  local UDOO_OLD=`cat /etc/hostname`
  local UDOO_NEW=$1
  UDOO_NEW=`echo $UDOO_NEW | tr -d " \t\n\r" `

  if grep -q "\s$UDOO_OLD\$" /etc/hosts 
  then 
    sed -e "s/\s$UDOO_OLD\$/\t$UDOO_NEW/g" -i /etc/hosts 
  else
    echo $'\n'127.0.0.1$'\t'"$UDOO_NEW" >> /etc/hosts
  fi
    
  echo $UDOO_NEW > /etc/hostname
  
  # CHECK

  [[ "$(cat /etc/hostname)" == "$UDOO_NEW" ]] && \
  [[ "$(cat /etc/hostname)" =~ "$UDOO_NEW" ]] || error
  
  ok "The hostname has been changed successfully!
Please reboot!"

}

ntpdate_rtc() {
#ntpdate_rtc()
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

ch_keyboard(){
#ch_keyboard($LOCALE)
  local LOCALE=$1

  [[ -z $LOCALE ]] && error "LOCALE cannot be empty"

  #Search in /usr/share/X11/xkb/rules/xorg.lst
  grep -qc " $LOCALE " $KBD_RULES || error "LOCALE not valid (not in $KBD_RULES)"

  #Search for /etc/default/keyboard
  [[ -f $KBD_DEFAULT ]] || error "$KBD_DEFAULT not found"

  if grep -qc XKBLAYOUT $KBD_DEFAULT
    then
      sed -e "s/XKBLAYOUT=.*/XKBLAYOUT=\"$LOCALE\"/" -i $KBD_DEFAULT
    else
      echo XKBLAYOUT=\"$LOCALE\" >> $KBD_DEFAULT
  fi

  (( $? )) && error "Cannot set keyboard layout as default setting"

  setxkbmap $LOCALE

  (( $? )) && error "Cannot set keyboard layout directly"

  ok "Locale has changed successfully!"

}

ch_timezone(){
#ch_timezone($ZONE)
  local ZONE
  ZONE=$1

  [[ -z $ZONE ]] && error "ZONE cannot be empty"

  # /usr/share/zoneinfo/ + ZONE
  [[ -f $ZONEINFO$ZONE ]] || error "$ZONEINFO$ZONE does not exist"

  [[ -f $ZONEFILE ]] && rm $ZONEFILE
  [[ -f $ZONETIME ]] && rm $ZONETIME

  # /etc/localtime -> /usr/share/zoneinfo/ + ZONE
  ln -s $ZONEINFO$ZONE $ZONEFILE && echo $ZONE > $ZONETIME

  (( $? )) && error "Cannot set current timezone"

  ok "Timezone has changed successfully!"
}

expand_fs() {
#expand_fs()
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

}

boot_vram() {  
#boot_vram($GPUMEM)

  local GPUMEM=$1
  declare -i GPUMEM
  
  [[ -z $GPUMEM ]] && error "GPUMEM cannot be empty"
  
  $SETENV memory "gpu_memory=${GPUMEM}M" || error

  sync
  
  ok "The RAM video variables has been changed successfully"

}

boot_printenv() {
#boot_printenv()
  local UDOO_ENV
  UDOO_ENV=`$PRINTENV 2>&1`

  (( $? )) && error "$UDOO_ENV"

  $PRINTENV 2>&1 
}

boot_mmcvars() {
#boot_mmcvars($MMCPART)

  local MMCPART=$1
  local MMCROOT
  local BOOT

  [[ -z $MMCPART ]] && error "MMCPART cannot be empty"

  #compose
  MMCROOT=${MMC}p${MMCPART}
  
  #check
  [[ ! -b $MMCROOT ]] && error "$MMCROOT is not a valid block device"

  #set
  BOOT=`$SETENV mmcpart $MMCPART 2>&1`
  (( $? )) && error "$BOOT"

  BOOT=`$SETENV mmcroot $MMCROOT 2>&1`
  (( $? )) && error "$BOOT"
  
  sync
  
  ok "The environment variables has been changed successfully"

}

boot_satavars() {
#boot_satavars($SATAPART)

  local SATAPART=$1
  local SATAROOT
  local BOOT

  [[ -z $SATAPART ]] && error "SATAPART cannot be empty"
  
  #compose
  SATAROOT=${SATADEV}${SATAPART}
  
  #check
  [[ ! -b $SATAROOT ]] && echo "$SATAROOT is not a valid block device" 1>&2
  
  #set
  BOOT=`$SETENV satapart $SATAPART 2>&1`
  (( $? )) && error "$BOOT"

  BOOT=`$SETENV sataroot $SATAROOT 2>&1`
  (( $? )) && error "$BOOT"
  
  sync
  
  ok "The sataboot environment variables has been changed successfully"

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

boot_default() {
#boot_default($BOOTSRC,$QUIET)
  local BOOTSRC=$1	
  local BOOT

  if [[ -n $BOOTSRC ]] 
    then 
      BOOT=`$SETENV src $BOOTSRC 2>&1`
      (( $? )) && error "$BOOT"
    else 
      error "BOOTSRC cannot be empty"
  fi
  
  ok "The default boot device is successfully changed!"
}

boot_script() {
#boot_script($SCRIPT)
  local BOOT
  local SCRIPT=$1

  [[ -z $SCRIPT ]] && error "SCRIPT cannot be empty"

  BOOT=`$SETENV script $SCRIPT 2>&1`
    (( $? )) && error "$BOOT"

  sync  

  ok "The boot script variable has been changed successfully"

}

boot_video() {
#boot_video($VIDEO_DEV,$VIDEO_RES)
  local VIDEO_DEV=$1
  local VIDEO_RES=$2
  local VIDEO

  [[ -z $VIDEO_DEV ]] && error "VIDEO_DEV cannot be empty"

  [[ -z $VIDEO_RES ]] && error "VIDEO_RES cannot be empty"

  VIDEO=`$SETENV video "video=mxcfb0:dev=$VIDEO_DEV,$VIDEO_RES" 2>&1`
  (( $? )) && error "$VIDEO"

  sync

  ok "The boot video variable has been changed successfully"
}

boot_reset(){
#boot_reset()

  local RESET 

  #Storing variables names
  RESET=`$PRINTENV 2>/dev/null | cut -d= -f1`
  (( $? )) && error $RESET

  #Wipe
  RESET=`echo $RESET | $SETENV -s - 2>&1`
  (( $? )) && error $RESET
  sync

  #Restore
  RESET=`$SETENV -s $SRCFILE 2>&1`
  (( $? )) && error $RESET
  sync

  ok "The u-boot environment has been resetted successfully"

}

startcamera(){
#startcamera($OPT)

if [[ -f $CAMERA_NOT_RUN ]] 
  then 
    rm $CAMERA_NOT_RUN
    service $CAMERA restart
  else 
    touch $CAMERA_NOT_RUN
    service $CAMERA stop
fi

(( $? )) && error

ok

}

credits() {
#credits() 
  cat <<CREDITS
UDOO Configurator Tool v2.1

Ettore Chimenti AKA ektor-5

ek5.chimenti@gmail.com

for UDOO Team @ 2014/12 
CREDITS
}

help() {
#help($OPTION)

case $1 in 
    ch_vncpasswd)cat <<HELP
Change vnc passwd
HELP
;;  
    ch_passwd);;        
    ch_host);;
    ntpdate_rtc);;
    ch_keyboard);;      
    ch_timezone);;      
    expand_fs);;
    boot_vram);;        
    boot_printenv);;
    boot_mmcvars);;     
    boot_mmcvars);;     
    boot_netvars);;     
    boot_default);;     
    boot_script);;      
    boot_video);;       
    boot_reset);;
    startcamera);;      
    credits);; 
    help);;             
    *);;
esac
}


usage(){
#usage()
  cat <<USAGE
$0: udoo-config [option] [ARGS...]

UDOO Configuration Tool 

Options:           ARGS:

ch_vncpasswd       PASSWD           Change VNC passwd
ch_passwd          USER, PASSWD     Change user passwd
ch_host            UDOO_NEW         Change hostname
ntpdate_rtc                         Update RTC upon NTP
ch_keyboard        LOCALE           Change keyboard mapping
ch_timezone        ZONE             Change Localzone
expand_fs                           Expand root partition
boot_vram          GPUMEM           Change GPU memory layout
boot_printenv                       Print uboot environment
boot_mmcvars       MMCPART          Change bootargs for mmc boot  
boot_satavars      SATAPART         Change bootargs for sata boot
boot_netvars       IPADDR SERVERIP  Change bootargs for network boot
                   NFSROOT GET_CMD  
boot_default       BOOTSRC QUIET    Change boot source
boot_script        SCRIPT           Load script
boot_video         VIDEO_DEV        Change video output [LDB|HDMI]
                   VIDEO_RES
boot_reset                          Reset u-boot environment
startcamera        OPT              Enable camera service
credits                             Shows the credits
USAGE
}
