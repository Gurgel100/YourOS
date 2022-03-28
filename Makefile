CURRENT_DIR := $(shell pwd)
CONFIG_DIR := $(CURRENT_DIR)/configs
SRC_DIR := $(CURRENT_DIR)/src
BOOTLOADER_SRC := $(SRC_DIR)/Bootloader
KERNEL_SRC := $(SRC_DIR)/Kernel
PROGRAM_SRCS := $(SRC_DIR)/Programs
TMPDIR := $(shell mktemp -d)
LOGDIR := $(TMPDIR)
IMG_FILES := $(TMPDIR)/files

BOOTLOADER_BIN := $(BOOTLOADER_SRC)/build/bootloader
KERNEL_BIN := $(KERNEL_SRC)/build/kernel
PROGRAM_BINS := $(PROGRAM_SRCS)/bin

CROSSTOOLS_DIR := $(CURRENT_DIR)/crosstools
TOOLCHAIN_DIR := $(CROSSTOOLS_DIR)/env
SYSROOT_DIR ?= $(TOOLCHAIN_DIR)

export PATH := $(PATH):$(TOOLCHAIN_DIR)/bin

.PHONY: all
all: YourOS.iso YourOS.hdd

YourOS.iso: image
	@echo "Generating iso image"
	@grub-mkrescue --output=$@ $(IMG_FILES) > $(LOGDIR)/mkrescue.txt 2>&1

YourOS.hdd: image
	@echo "Generating hd image"
	@./mk_hdd.sh $(IMG_FILES) $@ 104857600 $(TMPDIR)

.PHONY: release
release:
	@$(MAKE) BUILD_CONFIG=$@

.PHONY: image
image: bootloader kernel libc programs
#Prepare for iso generation
	@echo "Using tmpdir $(TMPDIR)"
	@mkdir -p $(IMG_FILES)/boot/grub
	@mkdir $(IMG_FILES)/bin
	@mkdir $(IMG_FILES)/dev

	@cp $(CONFIG_DIR)/grub.cfg $(IMG_FILES)/boot/grub/grub.cfg
	@cp $(BOOTLOADER_BIN) $(IMG_FILES)/bootloader
	@cp $(KERNEL_BIN) $(IMG_FILES)/kernel
	@cp $(PROGRAM_BINS)/* $(IMG_FILES)/bin/
	@cp $(CONFIG_DIR)/init.ini $(IMG_FILES)/init.ini

.PHONY: bootloader
bootloader:
	@echo "Compiling bootloader"
	@$(MAKE) BUILD_CONFIG=$(BUILD_CONFIG) -C $(BOOTLOADER_SRC)

.PHONY: kernel
kernel:
	@echo "Compiling kernel"
	@$(MAKE) BUILD_CONFIG=$(BUILD_CONFIG) -C $(KERNEL_SRC) kernel

.PHONY: libc
libc:
	@echo "Compiling libc"
	@$(MAKE) BUILD_CONFIG=$(BUILD_CONFIG) -C $(KERNEL_SRC) libc

.PHONY: install-headers
install-headers:
	@$(MAKE) SYSROOT_DIR=$(SYSROOT_DIR) -C $(KERNEL_SRC) install-headers

.PHONY: install-libc
install-libc: libc
	@$(MAKE) SYSROOT_DIR=$(SYSROOT_DIR) -C $(KERNEL_SRC) install-libc

.PHONY: programs
programs: install-libc
	@echo "Compiling programs"
	@$(MAKE) BUILD_CONFIG=$(BUILD_CONFIG) -C $(PROGRAM_SRCS)


.PHONY: clean
clean:
	@$(MAKE) -C $(BOOTLOADER_SRC) clean
	@$(MAKE) -C $(KERNEL_SRC) clean
	@$(MAKE) -C $(PROGRAM_SRCS) clean
	rm YourOS.iso
	rm YourOS.hdd