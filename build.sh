#!/bin/bash

#This script builds YourOS a free opensource operating system.

CORES=`nproc`
CURRENT_DIR=`pwd`
CROSSTOOLS_ELF_PREFIX=x86_64-elf-
CROSSTOOLS_OS_PREFIX=x86_64-pc-youros-
CROSSTOOLS_DIR=${CURRENT_DIR}/crosstools
TOOLCHAIN_DIR=${CROSSTOOLS_DIR}/env
BOOTLOADER_SRC=${CURRENT_DIR}/src/Bootloader
KERNEL_SRC=${CURRENT_DIR}/src/Kernel
PROG_SRC=${CURRENT_DIR}/src/Programs
OUTPUT=${CURRENT_DIR}/YourOS
CONFIG_DIR=${CURRENT_DIR}/configs
ERROR_OPT=false
REBUILD=false
DISASSEMBLE=false
MAKE_TARGET=

function die()
{
	echo -e "$1"
	exit -1
}

function help()
{
	echo "Usage: build.sh [options]"
	echo "Options:"
	echo " -h	Display this information"
	echo " -o	Output image name"
	echo " -f	Rebuild all (but not the toolchain)"
	echo " -s	Disassemble all binaries (useful for debugging)"
	echo " -r	Make a release build (enable otpimizations)"
}

#Start

echo "YourOS builder V0.1"

while getopts ":ho:frs" option; do
	case "${option}" in
		o)
			OUTPUT=${OPTARG}
			;;
		h)
			help
			exit 0
			;;
		f)
			REBUILD=true
			;;
		s)
			DISASSEMBLE=true
			;;
		r)
			MAKE_TARGET=release
			;;
		\?)
			echo "Invalid option -${OPTARG}" >&2
			ERROR_OPT=true
			;;
		:)
			echo -e "Option -${OPTARG} requires an argument" >&2
			ERROR_OPT=true
			;;
	esac
done

if [ ${ERROR_OPT} = true ]; then
	help
	exit 1
fi

echo "Checking for dependencies..."
(which make > /dev/null 2>&1) || die "Make is required"
(which grub-mkrescue > /dev/null 2>&1) || die "grub-mkrescue is required"

echo "Setting up..."

export PATH=${PATH}:${TOOLCHAIN_DIR}/bin

#Create tmp and build directory
TMPDIR=`mktemp -d`
LOGDIR=${TMPDIR}
IMG_FILES=${TMPDIR}/files

echo "Temp dir is ${TMPDIR}"

echo "Checking crosstools..."
if ! [ -e ${CROSSTOOLS_DIR}/crosstools_installed ]; then
	cd ${CROSSTOOLS_DIR}
	./build_crosstools.sh -k ${KERNEL_SRC} -d -c -t ${TMPDIR}/crosstools || die "Could not build crosstools"
fi

export CROSSTOOL_PREFIX=${CROSSTOOLS_ELF_PREFIX}

#Compile bootloader
echo "Building bootloader..."
cd ${BOOTLOADER_SRC}
if [ ${REBUILD} = true ]; then
	make clean
fi
make -j ${CORES} ${MAKE_TARGET} || die "Error during building of bootloader"
BOOTLOADER_BIN=${BOOTLOADER_SRC}/build/bootloader

#Compile kernel
echo "Building kernel and libc..."
cd ${KERNEL_SRC}
if [ ${REBUILD} = true ]; then
	make clean
fi
make -j ${CORES} ${MAKE_TARGET} || die "Error during building of kernel"
KERNEL_BIN=${KERNEL_SRC}/build/kernel

echo "Installing libc..."
cd ${KERNEL_SRC}
make -j ${CORES} SYSROOT_DIR=${TOOLCHAIN_DIR} install-libc || die "Error during installing of libc"

echo "Building programs..."
cd ${PROG_SRC}
if [ ${REBUILD} = true ]; then
	make clean
fi
make -j ${CORES} ${MAKE_TARGET} || die "Error during building of programs"
PROG_BINS=${PROG_SRC}/bin

#Prepare for iso generation
mkdir -p ${IMG_FILES}/boot/grub
mkdir ${IMG_FILES}/bin

cp ${CONFIG_DIR}/grub.cfg ${IMG_FILES}/boot/grub/grub.cfg
cp ${BOOTLOADER_BIN} ${IMG_FILES}/bootloader
cp ${KERNEL_BIN} ${IMG_FILES}/kernel
cp ${PROG_BINS}/* ${IMG_FILES}/bin/
cp ${CONFIG_DIR}/init.ini ${IMG_FILES}/init.ini

echo "Generating ISO file..."
${CURRENT_DIR}/mk_iso.sh ${IMG_FILES} ${OUTPUT}.iso > ${LOGDIR}/mkrescue.txt 2>&1 || die "Error while creating iso"

echo "Generating hd image..."
${CURRENT_DIR}/mk_hdd.sh ${IMG_FILES} ${OUTPUT}.hdd 104857600 ${TMPDIR}

if [ ${DISASSEMBLE} = true ]; then
	echo "Disassembling..."

	${CROSSTOOLS_ELF_PREFIX}objdump -D -S ${BOOTLOADER_BIN} > ${CURRENT_DIR}/disassembly_boot.S
	${CROSSTOOLS_ELF_PREFIX}objdump -D -S ${KERNEL_BIN} > ${CURRENT_DIR}/disassembly_kernel.S
fi

echo "Completed"
