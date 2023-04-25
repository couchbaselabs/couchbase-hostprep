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
centos|rhel|amzn|rocky|ol|fedora)
  yum install -q -y git
  ;;
ubuntu|debian)
  apt-get update
  apt-get install -q -y git
  ;;
opensuse-leap|sles)
  zypper install -y git
  ;;
arch)
  pacman-key --init
  pacman-key --populate
  pacman -Sy --noconfirm
  pacman -S --noconfirm git
  ;;
*)
  err_exit "Unknown Linux distribution $ID"
  ;;
esac

####
