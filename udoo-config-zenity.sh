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

error(){
  TEXT=$1
  [[ -z $TEXT ]] && TEXT="A fatal error has occoured!"
  $D --title="$TITLE" --error --text="$TEXT"
  exit 1
}

alert(){
  TEXT=$1
  [[ -z $TEXT ]] && TEXT="An error has occoured! Warning!"
  $D --title="$TITLE" --warning --text="$TEXT"
  return 0
}

question(){
  TEXT=$1
  [[ -z $TEXT ]] && TEXT="An error has occoured!"
  $D --title="$TITLE" --question --text="$TEXT"
  return $?
}

ok(){
  TEXT=$1
  [[ -z $TEXT ]] && 	TEXT="Success!"
  (( $QUIET )) || 	$D --title="$TITLE" --info --text="$TEXT"
  return 0
}

zdaemonctl(){

  local DAEMON
  local DAEMONS
  local DAEMON_CHOOSE_
  local LINE
  local DAEMON_CHOOSE
  local DAEMON_COMPARE

  declare -a DAEMON_CHOOSE DAEMON_COMPARE

  # while read LINE
  #  do
  #   DAEMON=`echo $LINE | cut -d" " -f1`
  # 
  #   if echo $LINE | grep -q on$ 
  #   then 
  #     DAEMONS="$DAEMONS TRUE $DAEMON"    
  #     #APPEND TO DAEMON_COMPARE ARRAY
  #      DAEMON_COMPARE[$I]=$DAEMON
  #   else
  #     DAEMONS="$DAEMONS FALSE $DAEMON"
  #   fi
  #   
  # done < <( daemonctl | sort -V | grep 0 -v )

  #SEMPLIFIED VERSION
  
  ##
  #LIST DAEMONS
  ##
  local QUIET=1 #no "success" message
  local I=1
  for DAEMON in ${DAEMON_LIST[@]}
  do
    echo DAE   $DAEMON #DEBUG
    LINE=`daemonctl $DAEMON`
    echo LINE  $LINE #DEBUG    
    echo LINE# ${LINE#* } #DEBUG

    if [[ "${LINE#* }" =~ "on" ]] 
    then 
      DAEMONS="$DAEMONS TRUE $DAEMON"
      #APPEND TO DAEMON_COMPARE ARRAY
      DAEMON_COMPARE[$I]=$DAEMON
      let I++
      echo on_!
    elif [[ "${LINE#* }" =~ "off" ]] 
    then
      echo off_!
      DAEMONS="$DAEMONS FALSE $DAEMON"
    fi
  done
  
  echo DAEMONS $DAEMONS #DEBUG
  
  DAEMON_CHOOSE_=`$D --title="$TITLE" \
		    --width=400 \
		    --height=300 \
		    --list \
		    --checklist \
		    --hide-header \
		    --print-column="ALL" \
		    --column="Checkbox" \
		    --column="Daemon" \
		    --text="Check the daemons you want to enable/disable" \
		    $DAEMONS \
		    `
  #NO CHOICE
  (( $? )) && exit 0 

  #FILL CHOOSED DAEMON ARRAY

  #case 1 element
  DAEMON_CHOOSE_="$DAEMON_CHOOSE_|"
  echo $DAEMON_CHOOSE_ #DEBUG

  I=1
  DAEMON_CHOOSE[$I]=`echo $DAEMON_CHOOSE_ | cut -d\| -f$I`
  while [[ -n ${DAEMON_CHOOSE[$I]} ]]
  do
    let I++
    DAEMON_CHOOSE[$I]=`echo $DAEMON_CHOOSE_ | cut -d\| -f$I`
  done

  echo LST_ ${DAEMON_LIST[@]} #DEBUG
  echo CMP_ ${DAEMON_COMPARE[@]} #DEBUG
  echo CHO_ ${DAEMON_CHOOSE[@]} #DEBUG

  # A	B	ACTION

  # Y	Y	Do nothing	CMP++ CHO++ LST++
  # Y	N	Turn off	CMP++	    LST++
  # N	Y	Turn on		      CHO++ LST++
  # N	N	Do nothing		    LST++

  local LST=0
  local CMP=1
  local CHO=1
  local A
  local B

  while [[ -n ${DAEMON_LIST[$LST]} ]]
  do 

  echo LST ${DAEMON_LIST[$LST]} #DEBUG  
  echo CMP ${DAEMON_COMPARE[$CMP]} #DEBUG
  echo CHO ${DAEMON_CHOOSE[$CHO]} #DEBUG

  #A
    if [[ ${DAEMON_LIST[$LST]} == ${DAEMON_COMPARE[$CMP]} ]]
    then 
      A=Y
      let CMP++
    else 
      A=N
    fi
  #B  
    if [[ ${DAEMON_LIST[$LST]} == ${DAEMON_CHOOSE[$CHO]} ]] 
    then 
      B=Y 
      let CHO++
    else 
      B=N
    fi
    
    
    echo FLG $A $B #DEBUG
    
    [[ $A != $B ]] && if [[ $A == "Y" ]]
      then
	daemonctl ${DAEMON_LIST[$LST]} off
      else
	daemonctl ${DAEMON_LIST[$LST]} on  
    fi

    let LST++
  done

  unset A B
  unset QUIET
  
  ok
}

zch_vncpasswd(){
  ## ch_vncpasswd 
  
  local PASSWD
  local PASSWR
  
  [[ ! -f $VNCPASSWD ]] && error "$VNCPASSWD not found! Is the VNC server installed?"
  
  PASSWD=`$D --title="$TITLE" --entry --text="Enter new password for remote desktop access" --hide-text`
  (( $? )) && exit 1
 
  [[ -z $PASSWD ]] && error "Password cannot be empty"

  ## DOUBLE CHECK
  PASSWR=`$D --title="$TITLE" --entry --text="Re-enter password" --hide-text` 

  [[ $PASSWD != $PASSWR ]] && error 'Sorry, passwords do not match'
      
  ch_vncpasswd $PASSWD
 
}

zch_passwd(){
  ## ch_passwd 
  
  local PASSWD
  local PASSWR
  
  PASSWD=`$D --title="$TITLE" --entry --text="Enter new user password" --hide-text`

  (( $? )) && exit 1
 
  [[ -z $PASSWD ]] && error "Password cannot be empty"

  ## DOUBLE CHECK
  PASSWR=`$D --title="$TITLE" --entry --text="Re-enter password" --hide-text` 

  [[ $PASSWD != $PASSWR ]] && error 'Sorry, passwords do not match'
      
  ch_passwd $UDOO_USER $PASSWD
 
}

zch_host(){
  local UDOO_OLD=`cat /etc/hostname`
  local UDOO_NEW
  UDOO_NEW=`$D --title="$TITLE" --entry --text="Enter hostname (current: $UDOO_OLD)" `
  
  (( $? )) && exit 1
  
  UDOO_NEW=`echo $UDOO_NEW | tr -d " \t\n\r" `
  
  [[ -z $UDOO_NEW ]] && error "Hostname cannot be empty"
 
  xhost +
 
  ch_host $UDOO_NEW 
}

zntpdate_rtc(){
  ntpdate_rtc
}

zch_keyboard(){

  #local UDOO_OLD=`grep XKBLAYOUT $KBD_DEFAULT | cut -d = -f 2 | tr -d \"`
  local UDOO_OLD=`setxkbmap -query | sed -e 's/^layout:\ *\(\w*\)/\1/p' -n`
  local UDOO_NEW
  local CURRENT
  
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
	  if [[ ${line% *} == $current ]]
	  #mark current for sorting
	    then echo 1_TRUE $line
	    else echo FALSE $line
	  fi
      fi 
    done < <(cat $KBD_RULES)
    #named pipe
  }
  
  
  UDOO_NEW=`take_locales $UDOO_OLD | sort | sed -e 's/1_//' | \
	      xargs $D \
	      --title="$TITLE" \
	      --list \
	      --text="Enter new keyboard locale" \
	      --width=400 \
	      --height=300 \
	      --radiolist \
	      --hide-header \
	      --print-column=2 \
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

  local UDOO_NEW
  local CONTINENT
  local ZONE
  
  #current
  if [[ -L $ZONEFILE ]]
  then
    local UDOO_OLD=`readlink $ZONEFILE | cut -d/ -f5-`
  elif [[ -f $ZONEFILE ]]
  then
    local UDOO_OLD=`cat $ZONEFILE | cut -d/ -f2-`
  else
    local UDOO_OLD=""
  fi 
  
  local CONT_OLD=${UDOO_OLD%/*}
  local ZONE_OLD=${UDOO_OLD#*/}
    
  take_continents()
  {
  #take_continents($OLD)
    local CURRENT=$1
    local CONT
    
    for CONT in ${ZONECONTINENTS[@]}
    do
      if [[ $CONT == $CURRENT ]]
      then
	echo TRUE \"$CONT\"
      else
	echo FALSE \"$CONT\"
      fi
    done
  }

  CONTINENT=`take_continents $CONT_OLD | xargs $D \
	      --title="$TITLE" \
	      --list \
	      --text="Enter your local zone" \
	      --width=400 \
	      --height=300 \
	      --radiolist \
	      --hide-header \
	      --column="Checkbox" \
	      --column="Keycode" \
	      `
  (( $? )) && exit 1
  
  take_zone()
  {
  #take_continents($CONTINENT $OLD)
    local CONTINENTS=$1
    local CURRENT=$2
    local CONT
    
    [[ -z $CONTINENTS ]] && error "CONTINENT cannot be empty"
    OIFS=$IFS
    IFS=$'\n'
    
    for CONT in `ls -1 ${ZONEINFO}${CONTINENTS}`
    do
      if [[ $CONT == $CURRENT ]]
      then
	echo TRUE \"$CONT\"
      else
	echo FALSE \"$CONT\"
      fi
    done
    
    IFS=$OIFS
  }

  ZONE=`take_zone $CONTINENT $ZONE_OLD | sed -e 's/_/ /g' | xargs $D \
	      --title="$TITLE" \
	      --list \
	      --text="Enter your local zone" \
	      --width=400 \
	      --height=300 \
	      --radiolist \
	      --hide-header \
	      --column="Checkbox" \
	      --column="Keycode" \
	      `
  (( $? )) && exit 1

  UDOO_NEW=`echo $CONTINENT/$ZONE | sed -e 's/\ /_/g' | tr -d "\t\n\r" `

  unset take_zone
  unset take_continents
  
  [[ -z $UDOO_NEW ]] && error "LOCALE cannot be empty"

  ch_timezone $UDOO_NEW
}

expand_fs(){
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

zboot_vram(){
  local UDOO_ENV
  local GPUMEM
  declare -i GPUMEM
   
  UDOO_ENV=`$PRINTENV memory 2>&1`

  case $? in
	  1)  	error "$UDOO_ENV \nTry resetting the uboot environment" ;;
	  127)	error "$PRINTENV not found" ;;
  esac

  GPUMEM=`echo $UDOO_ENV | sed -n -e 's/.*gpu_memory\=\([0-9]*\)M.*/\1/p'`

  (( $GPUMEM )) || GPUMEM=128

  current_video() {
  #current_video($OLD)
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
  
  local DESC=("1M" "8M" "16M" "32M" "64M" "128M (default)" "256M")
  local SRC=(1 8 16 32 64 128 256)

  GPUMEM=`current_video $GPUMEM | xargs $D --title="$TITLE" \
		  --width=400 \
		  --height=300 \
		  --list \
		  --radiolist \
		  --hide-header \
		  --hide-column=2 \
		  --column="Checkbox" \
		  --column="Number" \
		  --column="Option" \
		  --text="Choose a memory value for video card reserved memory:" \
		  `
  (( $? )) && exit 1
  
  unset current_video
  
  boot_vram $GPUMEM
}

zboot_printenv(){
  boot_printenv | $D --width=600 --height=500 --title="$TITLE" --text-info --font="monospace,9"
}

zboot_mmcvars(){
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

zboot_satavars(){
  local SATAPART
  local SATAROOT  
  local SATA
  local parts=0

  local -a DESC=('Partition 1 (default)' \
	      'Partition 2' \
	      'Partition 3' \
	      'Partition 4') 

  #Take only the ata- drive (one supported) and read the link 
  SATA=( `ls ${SATADRIVES}* -1 2>/dev/null | grep "part" -v` )
  
  if [[ ${#SATA[@]} == 1 ]]
  then 
    SATA="/dev/$(readlink $SATA | cut -d/ -f 3)"
  elif [[ ${#SATA[@]} > 1 ]]
  then
    #CHOOSE
    local i 
    for i in ${SATA[@]} ; do echo FALSE $i ; done

    local CHOOSE=`$D  \
	      --title="Choose your SATA boot drive" \
	      --width=400 \
	      --height=300 \
	      --list \
	      --text="It seems you've connected multiple ata devices. 
Choose the one you want to configure (if you have a usb device, exit and disconnect it)" \
	      --radiolist \
	      --hide-header \
	      --hide-column=2 \
	      --column="Checkbox" \
	      --column="Device" \
	      --column="Desc" \
	      $(for i in ${SATA[@]} ; do echo FALSE $i ${i##*ata-} ; done)`
    (( $? )) && exit 1
    SATA="/dev/$(readlink $CHOOSE | cut -d/ -f 3)"
  fi
  
  echo $SATA #DEBUG
  
  #CURRENT
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
  
  #or choose between 4 possible partition if
  if [[ $parts == 0 ]] 
  then 
    if [[ -b $SATA ]]
    then
    #no partitions
      parts=4
      question "No partition found on $SATA, check configuration.
Be careful on next step. Do you want to continue anyway?"
      (( $? )) && exit 1
    else
    #no drives
      parts=4
      question "No ata drive found, check configuration.
Be careful on next step. Do you want to continue anyway?"
      (( $? )) && exit 1
    fi
  fi
  
  if [[ $parts == 1 ]]
  then
    #set automatically
    SATAPART=1     
    question "Found 1 partition on $SATA. Selecting it as the boot partition.
Is this correct?"
    (( $? )) && exit 1
  else
    #or choose
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
  
zboot_netvars(){
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
  
  # Test IP address for validity
  valid_ip() {
      local ip=$1
      local stat=1

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
  
 
  #check  
  local ALERT
  local i=0
  
  #IPADDR 
  IPADDR_OLD=$IPADDR
  IPADDR=`echo $FORM | cut -d \| -f 1 | tr -d " "`  
  if [[ -z "$IPADDR" ]]
  then
    ALERT[$i]="IP Address will be obtained via DHCP"
    let i++
    IPADDR="dhcp"
  elif ! valid_ip $IPADDR
  then
    ALERT[$i]="IP Address is not valid, setting previous ($IPADDR_OLD)"
    let i++
    IPADDR=$IPADDR_OLD
  fi
  
  #SERVERIP
  SERVERIP_OLD=$SERVERIP
  SERVERIP=`echo $FORM | cut -d \| -f 2 | tr -d " "`
  if [[ -z "$SERVERIP" ]]
  then
    ALERT[$i]="SERVERIP cannot be empty, setting previous ($SERVERIP_OLD)"
    let i++
    SERVERIP=$SERVERIP_OLD
  elif ! valid_ip $SERVERIP
  then
    ALERT[$i]="SERVERIP is not valid, setting previous ($SERVERIP_OLD)" 
    let i++
    SERVERIP=$SERVERIP_OLD
  fi
  
  #NFSROOT
  NFSROOT_OLD=$NFSROOT
  NFSROOT=`echo $FORM | cut -d \| -f 3`
  if [[ -z "$NFSROOT" ]]
  then
    ALERT[$i]="NFSROOT cannot be empty, setting previous ($NFSROOT_OLD)" && \
    let i++
    NFSROOT=$NFSROOT_OLD
  elif [[ "$NFSROOT" =~ [^/a-zA-Z0-9] ]]
  then
    ALERT[$i]="The specified directory is not valid. \
    \nOnly alphanumeric characters are allowed in directories names. \
    \nSetting previous ($NFSROOT_OLD)"
    let i++
    NFSROOT=$NFSROOT_OLD
  fi
  
  unset valid_ip
  i=0
  #Print alerts if any
  if [[ -n ${ALERT[@]} ]]  
  then 
    question \
    "$(for i in `seq 0 ${#ALERT[@]}`; do echo ${ALERT[$i]} ; done )
    \nAre you sure?"
 
  (( $? )) && exit 0
  fi
  
  local DESC=('DHCP' "TFTP" "NTP")
  local SRC=('dhcp' 'tftp' 'ntp')
  
  current_getcmd()
  {
  #current_getcmd($CURRENT)
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

zboot_default(){
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

zboot_script(){
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

zboot_video(){
  local VIDEO_DEV
  local VIDEO_RES
  local VIDEO

  VIDEO=`$PRINTENV video 2>&1`
  (( $? )) && error "$VIDEO"

  VIDEO_DEV=`echo $VIDEO | cut -d "=" -f 4- | cut -d "," -f 1 `  # e.g. video=mxcfb0:dev=hdmi,1920x1080M@60,bpp=32
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

  local SRC=( "hdmi" "ldb1" "ldb2" )
  local DESC=( 'HDMI' 'LVDS 7 inch' 'LVDS 15 inch' )
  
  current_video() {
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
  
  VIDEO_DEV=`current_video $VIDEO_DEV | xargs $D --list \
		    --title="Set the video output environment variables" \
		    --radiolist \
		    --hide-header \
		    --hide-column=2 \
		    --column="Checkbox" \
		    --column="Option" \
		    --column="Video" \
		    --text="Default video device (current: $VIDEO_DEV)" \
		    `

  (( $? )) && exit 1

  [[ -z $VIDEO_DEV ]] && error "VIDEO_DEV cannot be empty"

  
  local SRC=( "1024x768@60,bpp=32" \
	      "1366x768@60,bpp=32" \
	      "1920x1080@60,bpp=32" )
  local DESC=( "1024x768" "1366x768" "1920x1080" )
  

  case $VIDEO_DEV in 
    hdmi) VIDEO_RES=`current_video $VIDEO_RES | xargs $D \
	      --list \
	      --title="Set the video output environment variables" \
	      --radiolist \
	      --hide-header \
	      --hide-column=2 \
	      --print-column=2 \
	      --column="Checkbox" \
	      --column="Option" \
	      --column="Desc" \
	      --text="Default resolution for video device" \
	  `
	  (( $? )) && exit 1
	  ;;
    
    ldb1) VIDEO_RES="LDB-WVGA,if=RGB666,bpp=32" 
	  VIDEO_DEV="ldb" ;;
    ldb2) VIDEO_RES="1366x768M@60,if=RGB24,bpp=32" 
	  VIDEO_DEV="ldb" ;;
  esac 
  
  unset current_video
  
  [[ -z $VIDEO_RES ]] && error "VIDEO_RES cannot be empty"
   
  boot_video $VIDEO_DEV $VIDEO_RES 
}

zboot_reset(){
#boot_reset()

  question "The u-boot environment stored in your SD is going to be erased and overwritten by this configurator's default values. 
You are advised to backup your actual environment before proceeding." \
  || exit 1

  boot_reset

}

zstartcamera(){

  [[ -d $CAMERA_DIR ]] || error "The Camera service seems to be not installed properly"

  if [[ $(service camera status) =~ "start" ]] 
    then
      question "Camera service is currently enabled and running. Do you want to disable it?" 
    else
      question "Camera service is currently disabled. Do you want to enable it?" 
  fi

  (( $? )) && exit
  
  startcamera
      
}

zboot_mgr(){
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
	    0		7		"Change RAM memory layout" \
	    0		8		"Reset U-Boot Environment" \
	    0		9		"Show U-Boot Environment" \
	  `  
    EXIT=$?
    
    case $CHOOSE in
      
      7) (zboot_vram) ;;
      
      8) (zboot_reset) ;;
    
      9) (zboot_printenv) ;;
      
    esac

  done
}

zsys_mgr(){
#DEPRECATED
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
	    0		7		"Expand root partition to disk max capacity" \
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

zcredits(){
 $D 	--title="Credits" --info --text="$(credits)"
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
	  --height=350 \
	  --list \
	  --text="Choose an option:" \
	  --radiolist \
	  --hide-header \
	  --hide-column=2 \
	  --column="Checkbox" \
	  --column="Number" \
	  --column="Option" \
	  0		1		"Change User Password" \
	  0		2		"Change Keyboard Layout" \
	  0		3		"Change Timezone Setting" \
	  0		4		"Change Remote Desktop Password" \
	  0		5		"Expand Filesystem to fill disk max capacity" \
	  0		6		"Set Default Boot Device" \
	  0		7		"Set Default Video Output (LVDS \ HDMI)" \
	  0		8		"Enable UDOO Camera Module" \
	  0		9		"U-Boot" \
	  0		10		"Credits" \
	      `
  EXIT=$?
  
  case $CHOOSE in

    1) (zch_passwd $UDOO_USER) ;;

    2) (zch_keyboard) ;;

    3) (zch_timezone) ;;
      
    4) (zch_vncpasswd) ;;
     
    5) (expand_fs) ;;   
  
    6) (zboot_default) ;;

    7) (zboot_video) ;;
    
    8) (zstartcamera) ;;

    9) (zboot_mgr) ;;   

    10) (zcredits) ;;

  esac

done
