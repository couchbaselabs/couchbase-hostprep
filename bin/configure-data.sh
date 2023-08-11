#!/bin/bash
# shellcheck disable=SC2181
# shellcheck disable=SC2034
#
DIR_NAME=$(dirname "$0")
SCRIPTDIR=$(cd "$DIR_NAME" && pwd)
PKGDIR=$(dirname "$SCRIPTDIR")
source "$PKGDIR/lib/libcommon.sh"
DATA_DEVICE=""
MOUNT_POINT="/cbdata"
SCRIPT_NAME=$(basename "$0")
LOGFILE=/var/log/${SCRIPT_NAME%.*}.log

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

if [ -z "$DATA_DEVICE" ]; then
  for DISK in $(lsscsi | grep -v sr0 | awk '{print $NF}')
  do
    mount | awk '{print $1}' | grep ^"${DISK}" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
      DATA_DEVICE=$DISK
      break
    fi
  done
fi

if [ -z "$DATA_DEVICE" ]; then
  echo "No data device available. Exiting."
  exit 1
fi

echo "Mounting $MOUNT_POINT on $DATA_DEVICE"

echo "Labeling disk"
parted "$DATA_DEVICE" --script -a optimal -- mklabel gpt >> "$LOGFILE" 2>&1
[ $? -ne 0 ] && err_exit "Can not label disk $DATA_DEVICE"

echo "Creating primary partition"
parted "$DATA_DEVICE" --script -a optimal -- mkpart primary 0% 100% >> "$LOGFILE" 2>&1
[ $? -ne 0 ] && err_exit "Can not partition disk $DATA_DEVICE"

partprobe "$DATA_DEVICE"

DISK_PARTITION=$(lsblk -nPf "$DATA_DEVICE" | tail -1 | cut -d\" -f2)

[ -z "$DISK_PARTITION" ] && err_exit "Can not determine disk partition device name"

echo "Creating filesystem"
mkfs -t ext4 "/dev/${DISK_PARTITION}" >> "$LOGFILE" 2>&1
[ $? -ne 0 ] && err_exit "Can not create filesystem on $DISK_PARTITION"

sync
file -s "/dev/$DISK_PARTITION" | tee -a "$LOGFILE"

DISK_UUID=$(blkid -o value -s UUID "/dev/$DISK_PARTITION")

[ -z "$DISK_UUID" ] && err_exit "Can not get UUID for device $DISK_PARTITION"

mkdir "$MOUNT_POINT"

echo "UUID=$DISK_UUID	$MOUNT_POINT ext4 defaults 0 1" >> /etc/fstab

echo "Mounting $MOUNT_POINT"
mount "$MOUNT_POINT"

echo "Done."
##