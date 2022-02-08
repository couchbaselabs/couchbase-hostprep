#!/bin/sh
#
SCRIPTDIR=$(cd $(dirname $0) && pwd)
PKGDIR=$(dirname $SCRIPTDIR)

curl -Is --connect-timeout 4 --retry 3 https://github.com >/dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "Can not connect to GitHub. Refresh cancelled."
fi

cd $PKGDIR
git pull -q
