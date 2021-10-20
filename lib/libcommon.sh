#!/bin/bash
#
#
function print_usage {
if [ -n "$PRINT_USAGE" ]; then
   echo "$PRINT_USAGE"
fi
}

function err_exit {
   if [ -n "$1" ]; then
      echo "[!] Error: $1"
   else
      print_usage
   fi
   exit 1
}

function warn_msg {
   if [ -n "$1" ]; then
      echo "[i] Warning: $1"
   fi
}

function info_msg {
   if [ -n "$1" ]; then
      echo "[i] Notice: $1"
   fi
}

function log_output {
    [ -z "$NOLOG" ] && NOLOG=0
    DATE=$(date '+%m-%d-%y_%H:%M:%S')
    HOSTNAME=$(uname -n)
    [ -z "$LOGFILE" ] && LOGFILE=/var/log/$(basename $0).log
    while read line; do
        [ -z "$line" ] && continue
        if [ "$NOLOG" -eq 0 -a -n "$LOGFILE" ]; then
           echo "$DATE $HOSTNAME: $line" | tee -a $LOGFILE
        else
           echo "$DATE $HOSTNAME: $line"
        fi
    done
}

function set_linux_type {
  source /etc/os-release
  export LINUXTYPE=$ID
  case $ID in
  centos)
    PKGMGR="yum"
    SVGMGR="systemctl"
    ;;
  *)
    err_exit "Unknown Linux distribution $ID"
    ;;
  esac
}

function install_pkg {
  case $PKGMGR in
  yum)
    yum install -y $@
    ;;
  *)
    err_exit "Unknown package manager $PKGMGR"
    ;;
  esac
}

function service_control {
  case $SVGMGR in
  systemctl)
    systemctl $@
    ;;
  *)
    err_exit "Unknown service manager $SVGMGR"
    ;;
  esac
}

function nm_check {
  case $LINUXTYPE in
  centos)
    local PKGNAME="NetworkManager"
    local SVCNAME=$PKGNAME
    ;;
  *)
    err_exit "Unknown linux type $PKGMGR"
    ;;
  esac

  which nmcli >/dev/null 2>&1
  if [ $? -ne 0 ]; then
    install_pkg $PKGNAME
    service_control enable $SVCNAME
    service_control start $SVCNAME
  fi
}

function prep_generic {
  log_output "Starting general host prep."
  set_linux_type
  log_output "System type: $LINUXTYPE"
  nm_check
}

function cb_install {
  log_output "Starting Couchbase server install."
  set_linux_type
  log_output "System type: $LINUXTYPE"
}
