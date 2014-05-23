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
  [[ -z $TEXT ]] && TEXT="A fatal error has occoured!"
  $D --title="$TITLE" --error --text="$TEXT"
  exit 1
}

alert() {
  TEXT=$1
  [[ -z $TEXT ]] && TEXT="An error has occoured! Warning!"
  $D --title="$TITLE" --warning --text="$TEXT"
  return 0
}

question() {
  TEXT=$1
  [[ -z $TEXT ]] && TEXT="An error has occoured!"
  $D --title="$TITLE" --question --text="$TEXT"
  return $?
}

ok() {
  TEXT=$1
  [[ -z $TEXT ]] && 	TEXT="Success!"
  (( $QUIET )) || 	$D --title="$TITLE" --info --text="$TEXT"
  return 0
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
 
  ch_host $UDOO_NEW 
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

  mem_split $FBMEM $GPUMEM
}

zprint_env()
{
  print_env | $D --width=400 --height=300 --title="$TITLE" --text-info --font="monospace,9"
}

zntpdate_rtc()
{
  ntpdate_rtc
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
  
  unset take_locales
  
  [[ $UDOO_NEW == $UDOO_OLD ]] && exit 1

  #UDOO_NEW=`echo $UDOO_NEW | tr -d " \t\n\r" `
    
  [[ -z $UDOO_NEW ]] && error "LOCALE cannot be empty"

  ch_keyboard $UDOO_NEW 
}

zch_timezone(){

  local UDOO_OLD=`readlink $ZONEFILE | cut -d/ -f5-`
  local UDOO_NEW
  local CONTINENT
  local ZONE
  
  take_continents()
  {
  #take_continents($UDOO_OLD)
  local CURRENT=`echo $1 | cut -d/ -f1`

  for CONT in ${ZONECONTINENTS[@]}
  do
    if [[ $CONT =~ $CURRENT ]]
    then
      echo TRUE $CONT
    else
      echo FALSE $CONT
    fi
  done
  }

  CONTINENT=`take_continents $UDOO_OLD | xargs $D --title="$TITLE" --list \
	      --text="Enter your geographic area" \
	      --width=400 \
	      --height=300 \
	      --radiolist \
	      --hide-header \
	      --print-column=2 \
	      --column="Checkbox" \
	      --column="Keycode" \
	      `

  (( $? )) && exit 1

  take_zone()
  {
  #take_continents($OLD $CONTINENT)
  local CURRENT=`echo $1 | cut -d/ -f2`
  local CONTINENT=$2

  for CONT in `ls $ZONEINFO$CONTINENT`
  do
    if [[ $CONT =~ $CURRENT ]]
    then
      echo TRUE \"$CONT\"
    else
      echo FALSE \"$CONT\"
    fi
  done
  }

  ZONE=`take_zone $UDOO_OLD $CONTINENT | sed -e 's/_/ /' | xargs $D --title="$TITLE" --list \
	      --text="Enter your local zone" \
	      --width=400 \
	      --height=300 \
	      --radiolist \
	      --hide-header \
	      --print-column=2 \
	      --column="Checkbox" \
	      --column="Keycode" \
	      `
  (( $? )) && exit 1

  UDOO_NEW=`echo $CONTINENT/$ZONE | tr -d " \t\n\r" | sed -e 's/ /_/'`

  unset take_zone
  unset take_continents
  
  [[ -z $UDOO_NEW ]] && error "LOCALE cannot be empty"

  ch_timezone $UDOO_NEW
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

zboot_mmcvars()
{
  local MMCPART
  local MMCROOT
  local -a DESC=('Partition 1 (default)' \
	      'Partition 2' \
	      'Partition 3' \
	      'Partition 4') 
  local parts=0
  
  MMCPART=`$PRINTENV mmcpart 2>&1`
  (( $? )) && error "$MMCPART"
  MMCPART=`echo -n $MMCPART | tail -c1`
  
  #part discovery in /dev/mmcblkp*
  [[ -b $MMC ]] || error "$MMC is not a valid MMC device file. Please check your configuration"
  
  local dev
  for dev in `ls ${MMC}?* 2>/dev/null`
  do
    let parts++
    [[ $parts -eq 4 ]] && break
  done
  unset dev
  
  [[ $parts == 0 ]] && error "No partition found on $MMC, check configuration"
  
  if [[ $parts == 1 ]]
  then
    #set automatically, don't ask
    MMCPART=1 
  else
    current_mmc()
    {
    #current_mmc($CURRENT)
      local CURRENT=$1
      local part
      local i=0
      
      #from 0 to lenght-1
      for part in `seq $parts`
      do
	if [[ $CURRENT == $part ]]
	then
	  echo TRUE $part \"${DESC[$i]}\"
	else
	  echo FALSE $part \"${DESC[$i]}\"
	fi
      let i++
      done
    }
    
    MMCPART=`current_mmc $MMCPART | xargs $D  \
	      --title="Choose your MMC boot partition" \
	      --width=400 \
	      --height=300 \
	      --list \
	      --text="Choose your MMC boot partition" \
	      --radiolist \
	      --hide-header \
	      --hide-column=2 \
	      --column="Checkbox" \
	      --column="Number" \
	      --column="Option"`

    (( $? )) && exit 1

    unset current_mmc
    
    [[ -z $MMCPART ]] && error "MMCPART cannot be empty"
  fi
  
  boot_mmcvars $MMCPART
  
}

zboot_satavars()
{
  local SATAPART
  local SATAROOT
  local parts=0
  local -a DESC=('Partition 1 (default)' \
	      'Partition 2' \
	      'Partition 3' \
	      'Partition 4') 

  SATAPART=`$PRINTENV satapart 2>&1`
  (( $? )) && error "$SATAPART"
  SATAPART=`echo -n $SATAPART | tail -c1`
  
  if [[ -b $SATA ]]
  then 
    #part discovery in /dev/sda* if exist
    local dev
    
    for dev in `ls ${SATA}? 2>/dev/null`
    do
      let parts++
      [[ $parts -eq 4 ]] && break
    done
    
    unset dev
  fi
  
  #or choose between 4 possible partition
  [[ $parts == 0 ]] && parts=4 && \
    question "No partition found on $SATA, check configuration.
Be careful on next step. Do you want to continue anyway?"
  (( $? )) && exit 1

  if [[ $parts == 1 ]]
  then
    #set automatically, don't ask
    SATAPART=1 
  else
    current_sata()
    {
    #current_sata($CURRENT)
      local CURRENT=$1
      local part
      local i=0
      
      #from 0 to lenght-1
      for part in `seq $parts`
      do
	if [[ $CURRENT == $part ]]
	then
	  echo TRUE $part \"${DESC[$i]}\"
	else
	  echo FALSE $part \"${DESC[$i]}\"
	fi
      let i++
      done
    }
    
    SATAPART=`current_sata $SATAPART | xargs $D  \
	      --title="Choose your SATA boot partition" \
	      --width=400 \
	      --height=300 \
	      --list \
	      --text="Choose your SATA boot partition" \
	      --radiolist \
	      --hide-header \
	      --hide-column=2 \
	      --column="Checkbox" \
	      --column="Number" \
	      --column="Option"`

    (( $? )) && exit 1

    unset current_sata
  fi

  [[ -z $SATAPART ]] && error "SATAPART cannot be empty"

  boot_satavars $SATAPART 
  
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
  IPADDR=`echo $IPADDR | cut -d= -f2`

  SERVERIP=`$PRINTENV serverip 2>&1`
  (( $? )) && error "$SERVERIP"
  SERVERIP=`echo $SERVERIP | cut -d= -f2`

  NFSROOT=`$PRINTENV nfsroot 2>&1` 
  (( $? )) && error "$NFSROOT"
  NFSROOT=`echo $NFSROOT | cut -d= -f2`

  GET_CMD=`$PRINTENV get_cmd 2>&1`
  (( $? )) && error "$GET_CMD"
  GET_CMD=`echo $GET_CMD | cut -d= -f2`


  FORM=`$D --forms --title="$TITLE" \
	  --text="Set the environment values for netboot" \
	  --add-entry="UDOO IP Address (current: $IPADDR) [leave blank for DHCP]" \
	  --add-entry="NTP Server IP Address (current: $SERVERIP)" \
	  --add-entry="NTP File System Location (current: $NFSROOT)" \
	`
  (( $? )) && exit 1
  
  # Test an IP address for validity
  function valid_ip()
  {
      local  ip=$1
      local  stat=1

      if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
	  OIFS=$IFS
	  IFS='.'
	  ip=($ip)
	  IFS=$OIFS
	  [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
	      && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
	  stat=$?
      fi
      return $stat
  }
  IPADDR_OLD=$IPADDR
  IPADDR=`echo $FORM | cut -d \| -f 1 | tr -d " "`  
  
  #check
  if [[ -z $IPADDR ]]
  then
    ALERT[0]="IP Address will be obtained via DHCP"
    IPADDR="dhcp"
  elif ! valid_ip $IPADDR
  then
    ALERT[0]="IP Address is not valid, setting default ($IPADDR_OLD)"
    IPADDR=$IPADDR_OLD
  fi
  SERVERIP_OLD=$SERVERIP
  
  SERVERIP=`echo $FORM | cut -d \| -f 2 | tr -d " "`
  if [[ -z  $SERVERIP ]]
  then
    ALERT[1]="SERVERIP cannot be empty, setting default ($SERVERIP_OLD)"
    SERVERIP=$SERVERIP_OLD
  elif ! valid_ip $SERVERIP
  then
    ALERT[1]="SERVERIP is not valid, setting default ($SERVERIP_OLD)" 
    SERVERIP=$SERVERIP_OLD
  fi
  
  NFSROOT_OLD=$NFSROOT
  NFSROOT=`echo $FORM | cut -d \| -f 3`
  [[ -z $NFSROOT ]] && \
    ALERT[2]="NFSROOT cannot be empty, setting default ($NFSROOT_OLD)" && \
    NFSROOT=$NFSROOT_OLD
  
  unset valid_ip

  #Print alerts
  [[ -n ${ALERT[@]} ]] && question \
    "$(for i in `seq 0 ${#ALERT[@]}`; do echo ${ALERT[$i]} ; done )
    
Are you sure?"
  (( $? )) && exit 0

  local DESC=('DHCP' "TFTP" "NTP")
  local SRC=('dhcp' 'tftp' 'ntp')
  
  current_getcmd()
  {
  #current_sata($CURRENT)
    local CURRENT=$1
    local get_cmd
    local i=0
    
    #from 0 to lenght-1
    for get_cmd in ${SRC[@]}
    do
      if [[ $CURRENT == $get_cmd ]]
      then
	echo TRUE $get_cmd \"${DESC[$i]}\"
      else
	echo FALSE $get_cmd \"${DESC[$i]}\"
      fi
    let i++
    done
  }

  GET_CMD=`current_getcmd $GET_CMD | xargs $D \
	  --title="$TITLE" \
	  --text="uImage Retrival Method (current: $GET_CMD)" \
	  --width=400 \
	  --height=300 \
	  --list \
	  --radiolist \
	  --hide-header \
	  --print-column=2 \
	  --hide-column=2 \
	  --column="Checkbox" \
	  --column="Method" \
	  --column="Description" \
	  `  
  (( $? )) && exit 1
  unset current_getcmd

  [[ -z $GET_CMD ]] && error "You have to specify a retrival method"

  boot_netvars $IPADDR $SERVERIP $NFSROOT $GET_CMD 

}

zboot_default()
{
  local BOOTSRC
  local BOOT
  local SRC=('mmc' 'sata' 'net')
  local DESC=('MicroSD Card' 'SATA Drive' 'Network FileSystem')
  
  BOOT=`$PRINTENV src 2>&1`
  (( $? )) && error "$BOOT"
  
  #remove "src=" from string 
  BOOT=`echo $BOOT | cut -d= -f2`
  
  current_default()
  {
  #current_default($CURRENT)
    local CURRENT=$1
    local i=0
    local src 
    
    #from 0 to lenght-1
    for src in ${SRC[@]}
    do
      if [[ $CURRENT == $src ]]
      then
	echo TRUE $src \"${DESC[$i]}\"
      else
	echo FALSE $src \"${DESC[$i]}\"
      fi
    let i++
    done
  }
  
  BOOTSRC=`current_default $BOOT | xargs $D  \
	    --title="Default Boot Drive" \
	    --width=400 \
	    --height=300 \
	    --list \
	    --text="Choose a default boot drive.
U-Boot will try first to boot up the system from there." \
	    --radiolist \
	    --hide-header \
	    --hide-column=2 \
	    --column="Checkbox" \
	    --column="Number" \
	    --column="Option"`

  (( $? )) && exit 1
  
  unset current_default
  
  #set variables
  zboot_${BOOTSRC}vars
  (( $? )) && exit 1

  if [[ -n $BOOTSRC ]] 
    then
      QUIET=1
      boot_default $BOOTSRC
      unset QUIET
    else 
      exit 
  fi
}

zboot_script()
{
#not useful now
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

  boot_script $SCRIPT
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

  boot_video $VIDEO_DEV $VIDEO_RES 
}

zboot_reset(){
#boot_reset()

  $D --question \
	--text="The u-boot environment stored in your SD is going to be erased and overwritten by this configurator's default values. 
You are advised to backup your actual environment before proceeding." || exit 1

  boot_reset

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
	  0		6		"Set default video output" \
	  0		7		"Change RAM memory layout" \
	  0		8		"Reset U-Boot Environment" \
	  0		9		"Show U-Boot Environment" \
	`  
  EXIT=$?
  
  case $CHOOSE in

    1) (zboot_default) ;;

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

if [[ 0 -lt $#  ]]
then
  COMMAND=$1
  shift
  
  $COMMAND $@
  
  E_CODE=$?
  case $E_CODE in
  127) usage ;; 
    *);;
  esac
  
  exit $E_CODE
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
