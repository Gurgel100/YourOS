#!/bin/bash

#Start
INPUT=${1}
OUTPUT=${2}
SIZE=${3}
TMPDIR=${4}

SECTOR_SIZE=512
SECTOR_COUNT=`expr ${SIZE} / ${SECTOR_SIZE}`
SECTOR_PART_START=2048

function die()
{
	echo -e "$1"
	exit -1
}

#Generate image
dd if=/dev/zero of=${OUTPUT} bs=${SECTOR_SIZE} count=${SECTOR_COUNT} > /dev/null || die "Could not create image file"

#Create primary partition
fdisk ${OUTPUT} <<EOF
n
p
1
${SECTOR_PART_START}

a
w
EOF

#Create loop devices
LOOP_DEV=`sudo losetup -f ${OUTPUT} --show` || die "Could not create dev loop device"
LOOP_PART=`sudo losetup -f ${OUTPUT} --offset=$((SECTOR_PART_START * SECTOR_SIZE)) --show`
if [ $? -ne 0 ]; then
	sudo losetup -d ${LOOP_DEV}
	die "Could not create part loop device"
fi

#Create ext2 filesystem
sudo mkfs.ext2 -q ${LOOP_PART} -L YourOS
if [ $? -ne 0 ]; then
	sudo losetup -d ${LOOP_DEV}
	sudo losetup -d ${LOOP_PART}
	die "Could not create filesystem"
fi

#Mount partition
MOUNT_PATH=${TMPDIR}/mnt
mkdir -p ${MOUNT_PATH}
sudo mount ${LOOP_PART} ${MOUNT_PATH}
sudo chmod 777 -R ${MOUNT_PATH}

#Copy files
cp -r ${INPUT}/* ${MOUNT_PATH}

#Install grub
sudo grub-install --root-directory=${MOUNT_PATH} --no-floppy ${LOOP_DEV}

#Cleanup
sudo umount ${MOUNT_PATH}
sudo losetup -d ${LOOP_DEV}
sudo losetup -d ${LOOP_PART}
