#!/bin/bash
# shellcheck disable=SC2181
# shellcheck disable=SC2034
#
DIR_NAME=$(dirname "$0")
SCRIPTDIR=$(cd "$DIR_NAME" && pwd)
PKGDIR=$(dirname "$SCRIPTDIR")
source "$PKGDIR/lib/libcommon.sh"
SWAP_DEVICE=""
SCRIPT_NAME=$(basename "$0")
LOGFILE=/var/log/${SCRIPT_NAME%.*}.log

PRINT_USAGE="Usage: $0 [ options ]
             -d Data device
             -m Mount point"

while getopts "d:" opt
do
  case $opt in
    d)
      SWAP_DEVICE=$OPTARG
      ;;
    \?)
      print_usage
      exit 1
      ;;
  esac
done
shift $((OPTIND -1))

if [ -z "$SWAP_DEVICE" ]; then
  for DISK in $(lsscsi | grep -v sr0 | awk '{print $NF}')
  do
    mount | awk '{print $1}' | grep ^"${DISK}" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
      SWAP_DEVICE=$DISK
      break
    fi
  done
fi

if [ -z "$SWAP_DEVICE" ]; then
  echo "No swap device available. Exiting."
  exit
fi

echo "Configuring swap on $SWAP_DEVICE"

mkswap "$SWAP_DEVICE"
swapon "$SWAP_DEVICE"
echo "$SWAP_DEVICE none swap sw 0 0" >> /etc/fstab
config_swappiness 1

##