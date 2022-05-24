#!/bin/bash
#
SCRIPTDIR=$(cd $(dirname $0) && pwd)
PKGDIR=$(dirname $SCRIPTDIR)
source $PKGDIR/lib/libcommon.sh
TYPE="generic"
CB_VERSION="7.0.3-7031"
SGW_VERSION="3.0.0"
PKGMGR="yum"
SVGMGR="systemctl"
ADMINUSER="admin"
PRINT_USAGE="Usage: $0 -t [ -v | -n | -d | -h | -u | -U | -c ]
             -t Host type
             -v Couchbase version
             -n DNS server
             -d DNS domain
             -h Hostname
             -u Admin username
             -U Non-root user to pattern
             -c Call function from library and exit"

while getopts "t:v:n:d:h:u:U:c:g:" opt
do
  case $opt in
    t)
      TYPE=$OPTARG
      ;;
    v)
      CB_VERSION=$OPTARG
      ;;
    g)
      SGW_VERSION=$OPTARG
      ;;
    n)
      NAMESERVER=$OPTARG
      ;;
    d)
      DOMAIN=$OPTARG
      ;;
    h)
      HOSTNAME=$OPTARG
      ;;
    u)
      ADMINUSER=$OPTARG
      ;;
    U)
      COPYUSER=$OPTARG
      ;;
    c)
      "$OPTARG"
      exit
      ;;
    \?)
      print_usage
      exit 1
      ;;
  esac
done
shift $((OPTIND -1))

if [ "$(id -u)" -ne 0 ]; then
  err_exit "You must run this utility as root."
fi

case $TYPE in
  generic)
    prep_generic
    enable_docker
    disable_firewall
    enable_chrony
    ;;
  cbnode)
    prep_generic
    cb_install
    disable_firewall
    enable_chrony
    ;;
  couchbase)
    prep_couchbase
    cb_install
    disable_firewall
    enable_chrony
    ;;
  sdk)
    prep_sdk
    enable_chrony
    ;;
  sgw)
    prep_sgw
    disable_firewall
    enable_chrony
    ;;
  basic)
    prep_basic
    ;;
  *)
    err_exit "Unknown node type $TYPE"
    ;;
esac
