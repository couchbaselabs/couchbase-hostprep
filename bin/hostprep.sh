#!/bin/sh
#
SCRIPTDIR=$(cd $(dirname $0) && pwd)
PKGDIR=$(dirname $SCRIPTDIR)
source $PKGDIR/lib/libcommon.sh
PRINT_USAGE="Usage: $0 [ -v | -d ]
             -v Couchbase version
             -n DNS server
             -d DNS domain"

echo $PKGDIR
info_msg "test"