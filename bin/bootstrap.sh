#!/bin/bash
#

source /etc/os-release
echo "Bootstrap linux type $ID"
case ${ID:-null} in
centos)
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
