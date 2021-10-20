#!/bin/sh
#
SCRIPTDIR=$(cd $(dirname $0) && pwd)
PKGDIR=$(dirname $SCRIPTDIR)
source $PKGDIR/lib/libcommon.sh
TYPE="generic"
VERSION="7.0.2-6703"
PKGMGR="yum"
SVGMGR="systemctl"
PRINT_USAGE="Usage: $0 -t [ -v | -n | -d | -h ]
             -t Host type
             -v Couchbase version
             -n DNS server
             -d DNS domain
             -h Hostname"

while getopts "t:v:n:d:h:" opt
do
  case $opt in
    t)
      TYPE=$OPTARG
      ;;
    v)
      VERSION=$OPTARG
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
    ;;
  cbnode)
    prep_generic
    cb_install
    ;;
  *)
    err_exit "Unknown node type $TYPE"
    ;;
esac
