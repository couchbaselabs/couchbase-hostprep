#!/bin/bash
#
SCRIPTDIR=$(cd $(dirname $0) && pwd)
PKGDIR=$(dirname $SCRIPTDIR)
PKGNAME=$(basename $PKGDIR)

curl -Is --connect-timeout 4 --retry 3 https://github.com >/dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "Can not connect to GitHub. Refresh cancelled."
fi

echo -n "Refreshing $PKGNAME ... "
cd $PKGDIR
git pull -q
if [ $? -eq 0 ]; then
  echo "Done."
else
  echo "Refresh Failed."
fi

####