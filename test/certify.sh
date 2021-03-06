#!/bin/bash
#
host_prep_repo="mminichino/hostprep"
sgw_version="3.0.0"
test_bootstrap=0
hostprep_opts=""

err_exit() {
   if [ -n "$1" ]; then
      echo "[!] Error: $1"
   fi
   exit 1
}

while getopts "bt:" opt
do
  case $opt in
    b)
      test_bootstrap=1
      ;;
    t)
      hostprep_opts="$hostprep_opts -p $OPTARG"
      ;;
    \?)
      echo "Usage: $0 [ -b ]"
      exit 1
      ;;
  esac
done
shift $((OPTIND -1))

which yum >/dev/null 2>&1
if [ $? -eq 0 ]; then
  cb_version="7.1.0-2556"
else
  cb_version="7.1.0-2556-1"
fi

if [ "$test_bootstrap" -eq 1 ]; then
  echo "Testing bootstrap"

  curl -sfL https://raw.githubusercontent.com/${host_prep_repo}/main/bin/bootstrap.sh | sudo -E bash -

  if [ $? -ne 0 ]; then
    echo "Problem encountered, stopping test."
    exit 1
  fi

  echo "Done."
fi

echo "Testing repo pull"

if [ -d /usr/local/hostprep ]; then
  echo -n "Removing existing hostprep installation ... "
  sudo rm -rf /usr/local/hostprep || err_exit "can not remove existing installation."
  echo "Done."
fi

sudo git clone https://github.com/${host_prep_repo} /usr/local/hostprep

if [ $? -ne 0 ]; then
  echo "Problem encountered, stopping test."
  exit 1
fi

echo "Done."

echo "Testing Couchbase prep"

sudo /usr/local/hostprep/bin/hostprep.sh -t couchbase -v ${cb_version} $hostprep_opts

if [ $? -ne 0 ]; then
  echo "Problem encountered, stopping test."
  exit 1
fi

echo "Done."

echo "Testing Sync Gateway pull"

sudo /usr/local/hostprep/bin/hostprep.sh -t sgw -g ${sgw_version} $hostprep_opts

if [ $? -ne 0 ]; then
  echo "Problem encountered, stopping test."
  exit 1
fi

echo "Done."
