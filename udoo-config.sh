#!/bin/bash

####################
#
# UDOO Config Main
#
####################

## Ettore Chimenti @ 2014/04


TITLE="UDOO Configuration Tool"

D="zenity"
PRINTENV="fw_printenv"
SETENV="fw_setenv"
NTPDATE="ntpdate-debian"
CHKCONF="chkconfig"
UDOO_USER="ubuntu"
MMC="/dev/mmcblk0"
PART="/dev/mmcblk0p1"
SRCFILE="udoo-defaultenv.src"
INSSERV="/usr/lib/insserv/insserv"

ZONEFILE="/etc/localtime"
ZONEINFO="/usr/share/zoneinfo/"

KBD_DEFAULT="/etc/default/keyboard"
KBD_RULES="/usr/share/X11/xkb/rules/xorg.lst"


[[ -f /etc/udoo-config.conf ]] && . /etc/udoo-config.conf

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/udoo-functions.sh

if [ $(id -u) -ne 0 ] 
then
  error "You're not root! Try execute: sudo udoo-config.sh" 2
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
