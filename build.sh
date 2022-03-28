#!/bin/bash

#This script builds YourOS a free opensource operating system.

CORES=`nproc`
CURRENT_DIR=`pwd`
CROSSTOOLS_DIR=${CURRENT_DIR}/crosstools
TOOLCHAIN_DIR=${CROSSTOOLS_DIR}/env
BOOTLOADER_SRC=${CURRENT_DIR}/src/Bootloader
KERNEL_SRC=${CURRENT_DIR}/src/Kernel
PROG_SRC=${CURRENT_DIR}/src/Programs
ERROR_OPT=false
REBUILD=false
DISASSEMBLE=false
BUILD_CONFIG=
BUILD_DOCKER=false
BUILD_IMAGE=false

function die()
{
	echo -e "$1"
	exit -1
}

function help()
{
	echo "Usage: build.sh [options]"
	echo "Options:"
	echo " -d	Build Docker container"
	echo " -h	Display this information"
	echo " -f	Rebuild all (but not the toolchain)"
	echo " -s	Disassemble all binaries (useful for debugging)"
	echo " -r	Make a release build (enable otpimizations)"
	echo " -v	Additionally build a hard drive image"
}

#Start

echo "YourOS builder V0.1"

while getopts ":dhfrsv" option; do
	case "${option}" in
		d)
			BUILD_DOCKER=true
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
			BUILD_CONFIG=release
			;;
		v)
			BUILD_IMAGE=true
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

if [ ${BUILD_DOCKER} = true ]; then
	echo "Building Docker container..."
	INCLUDE_DIR=${CROSSTOOLS_DIR}/include
	mkdir -p ${INCLUDE_DIR} \
	&& make -C ${KERNEL_SRC} SYSROOT_DIR=${CROSSTOOLS_DIR} install-headers \
	&& docker build --pull -t youros ${CROSSTOOLS_DIR}
	rm -r ${INCLUDE_DIR}
else

echo "Checking for dependencies..."
(which make > /dev/null 2>&1) || die "Make is required"
(which grub-mkrescue > /dev/null 2>&1) || die "grub-mkrescue is required"

echo "Checking crosstools..."
export PATH=${PATH}:${TOOLCHAIN_DIR}/bin
if ! [[	\
		-x "$(command -v x86_64-elf-gcc)"		\
		&& -x "$(command -v x86_64-elf-ld)"		\
		&& -x "$(command -v x86_64-pc-youros-gcc)"	\
		&& -x "$(command -v x86_64-pc-youros-ld)"	\
	]];
then
	cd ${CROSSTOOLS_DIR}
	./build_crosstools.sh -k ${KERNEL_SRC} -d -c || die "Could not build crosstools"
fi

if [ ${REBUILD} = true ]; then
	make clean
fi

if [ ${BUILD_IMAGE} = true ]; then
	MAKE_TARGET=all
else
	MAKE_TARGET=YourOS.iso
fi

make BUILD_CONFIG=${BUILD_CONFIG} -j ${CORES} ${MAKE_TARGET}

if [ ${DISASSEMBLE} = true ]; then
	echo "Disassembling..."
	
	BOOTLOADER_BIN=${BOOTLOADER_SRC}/build/bootloader
	KERNEL_BIN=${KERNEL_SRC}/build/kernel

	x86_64-elf-objdump -D -S ${BOOTLOADER_BIN} > ${CURRENT_DIR}/disassembly_boot.S
	x86_64-elf-objdump -D -S ${KERNEL_BIN} > ${CURRENT_DIR}/disassembly_kernel.S
fi

fi

echo "Completed"
