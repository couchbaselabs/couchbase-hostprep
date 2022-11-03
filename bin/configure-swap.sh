#!/bin/bash
#
SCRIPTDIR=$(cd $(dirname $0) && pwd)
PKGDIR=$(dirname $SCRIPTDIR)
source $PKGDIR/lib/libcommon.sh
CONFIGURE=0
FILE_SIZE=0
SWAP_DEVICE=""
SWAP_ON=""
WRITE_MODE=0
READ_MODE=0

PRINT_USAGE="Usage: $0 [ options ]
             -o Configure swap true/false
             -w Write config file
             -r Read config file
             -f Swap file size
             -d Swap device"

while getopts "o:f:d:wr" opt
do
  case $opt in
    o)
      if [ "$OPTARG" = "true" ]; then
        CONFIGURE=1
      fi
      ;;
    f)
      FILE_SIZE=$OPTARG
      ;;
    d)
      SWAP_DEVICE=$OPTARG
      ;;
    w)
      WRITE_MODE=1
      ;;
    r)
      READ_MODE=1
      ;;
    \?)
      print_usage
      exit 1
      ;;
  esac
done
shift $((OPTIND -1))

if [ "$WRITE_MODE" -eq 1 ]; then
  echo "${CONFIGURE}:${SWAP_DEVICE}" > /etc/swap-dev.conf
  exit
fi

if [ "$READ_MODE" -eq 1 ]; then
  if [ ! -f /etc/swap-dev.conf ]; then
    echo "Config file /etc/swap-dev.conf not found"
    exit
  fi
  CONFIGURE=$(cat /etc/swap-dev.conf | cut -f1 -d:)
  SWAP_DEVICE=$(cat /etc/swap-dev.conf | cut -f2 -d:)
fi

if [ $CONFIGURE -eq 1 ]; then
  if [ -n "$SWAP_DEVICE" ]; then
    check_device $SWAP_DEVICE
    if [ $? -ne 0 ]; then
      echo "Device $SWAP_DEVICE ineligible, attempting to locate alternative"
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
