#!/bin/bash
#

err_exit() {
   if [ -n "$1" ]; then
      echo "[!] Error: $1"
   fi
   exit 1
}

source /etc/os-release
echo "Bootstrap linux type $ID"
case ${ID:-null} in
centos|rhel)
  yum install -q -y git
  ;;
ubuntu)
  apt-get update
  apt-get install -q -y git
  ;;
*)
  err_exit "Unknown Linux distribution $ID"
  ;;
esac

####
