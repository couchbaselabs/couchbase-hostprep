#!/bin/sh
#
SCRIPTDIR=$(cd $(dirname $0) && pwd)
PKGDIR=$(dirname $SCRIPTDIR)
source $PKGDIR/lib/libcommon.sh
TYPE="generic"
VERSION="7.0.2-6703"
PRINT_USAGE="Usage: $0 -t [ -v | -n | -d ]
             -t Host type
             -v Couchbase version
             -n DNS server
             -d DNS domain"

while getopts "t:v:n:d:" opt
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
  \?)
    err_exit "Unknown node type $TYPE"
    ;;
esac
