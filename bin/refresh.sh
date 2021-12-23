#!/bin/sh
#
SCRIPTDIR=$(cd $(dirname $0) && pwd)
PKGDIR=$(dirname $SCRIPTDIR)

cd $PKGDIR
git pull
