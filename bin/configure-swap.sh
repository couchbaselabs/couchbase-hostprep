#!/bin/bash
#
SCRIPTDIR=$(cd $(dirname $0) && pwd)
PKGDIR=$(dirname $SCRIPTDIR)
source $PKGDIR/lib/libcommon.sh
CONFIGURE=0
FILE_SIZE=0
SWAP_DEVICE=""
SWAP_ON=""

PRINT_USAGE="Usage: $0 [ options ]
             -o Configure swap true/false
             -f Swap file size
             -d Swap device"

while getopts "o:f:d:" opt
do
  case $opt in
    o)
      if ["$OPTARG" = "true" ]; then
        CONFIGURE=1
      fi
      ;;
    f)
      FILE_SIZE=$OPTARG
      ;;
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

if [ $CONFIGURE -eq 1 ]; then
  if [ -n "$SWAP_DEVICE" ]; then
    lsblk $SWAP_DEVICE > /dev/null 2>&1
    if [ $? -ne 0 ]; then
      echo "Device $SWAP_DEVICE not found, attempting to locate alternative"
      SWAP_DEVICE=$(find_swap_device)
    fi
    SWAP_ON=$SWAP_DEVICE
  else
    if [ -n "$FILE_SIZE" ]; then
      SWAP_SIZE=$FILE_SIZE
    else
      SWAP_SIZE=$(free -b | awk '{print $2}' | head -2 | tail -1)
    fi
    SWAP_ON="/swapfile"
    fallocate -l ${SWAP_SIZE} ${SWAP_ON}
    chmod 600 ${SWAP_ON}
  fi

  if [ -z "$SWAP_ON" ]; then
    echo "No swap device available. Exiting."
    exit
  fi

  mkswap $SWAP_ON
  swapon $SWAP_ON
  echo "$SWAP_ON none swap sw 0 0" >> /etc/fstab
  config_swappiness 1
fi
