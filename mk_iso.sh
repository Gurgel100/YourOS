#!/bin/sh

#Start
INPUT=${1}
OUTPUT=${2}

grub-mkrescue --output=${OUTPUT} ${INPUT}

