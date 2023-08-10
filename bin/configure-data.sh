#!/bin/bash
#
DIR_NAME=$(dirname "$0")
SCRIPTDIR=$(cd "$DIR_NAME" && pwd)
PKGDIR=$(dirname "$SCRIPTDIR")
source "$PKGDIR/lib/libcommon.sh"
DATA_DEVICE="/dev/sdb"
MOUNT_POINT="/cbdata"

PRINT_USAGE="Usage: $0 [ options ]
             -d Data device
             -m Mount point"

while getopts "d:m:" opt
do
  case $opt in
    d)
      DATA_DEVICE=$OPTARG
      ;;
    m)
      MOUNT_POINT=$OPTARG
      ;;
    \?)
      print_usage
      exit 1
      ;;
  esac
done
shift $((OPTIND -1))

check_device "$DATA_DEVICE"
if [ $? -ne 0 ]; then
  echo "Device $DATA_DEVICE ineligible, attempting to locate alternative"
  DATA_DEVICE=$(find_swap_device)
fi

if [ -z "$DATA_DEVICE" ]; then
  echo "No data device available. Exiting."
  exit
fi

echo "Mounting $MOUNT_POINT on $DATA_DEVICE"

parted "$DATA_DEVICE" --script -a optimal -- mklabel gpt
parted "$DATA_DEVICE" --script -a optimal -- mkpart primary 0% 100%

partprobe "$DATA_DEVICE"

DISK_PARTITION=$(lsblk -nPf "$DATA_DEVICE" | tail -1 | cut -d\" -f2)

mkfs -t ext4 "/dev/${DISK_PARTITION}"

sync

DISK_UUID=$(lsblk -nPf "/dev/$DISK_PARTITION" | cut -d\" -f8)

[ -z "$DISK_UUID" ] && err_exit "Can not get UUID for device $DISK_PARTITION"

mkdir "$MOUNT_POINT"

echo "UUID=$DISK_UUID	$MOUNT_POINT ext4 defaults 0 1" >> /etc/fstab

mount "$MOUNT_POINT"

echo "Done."
##