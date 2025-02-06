#!/bin/bash

# SPDX-License-Identifier: Unlicense
# This is free and unencumbered software released into the public domain

set -e
set -u

usage()
{
    echo "Usage: $(basename "$0") [-c CONFIG] SUBCMD"
    echo
    echo "    SUBCMD can be:"
    echo "        - toolchain     install crosstool-NG locally and build toolchain"
    echo "        - pmufw-build   build the PMUFW"
    echo "        - pmufw-clean   remove the intermediate PMUFW build output"
    echo
    echo "    CONFIG is an optional configuration preset for a specific SoM or board."
    echo "    Available configs:"
    echo "        - kria          AMD/Xilinx Kria SoM"
    echo "        - k26           Same as 'kria' (deprecated: kria covers both k26 and k24)"
}

# $1: exit value
# $2: message
usage_exit()
{
    (
	echo "${2:-}"
	usage
    ) >&2
    exit "${1}"
}

build_toolchain()
{
    cp ct-ng.defconfig crosstool-ng/.config

    cd crosstool-ng/
    ./bootstrap
    ./configure --enable-local
    make
    ./ct-ng olddefconfig
    ./ct-ng build
}

pmufw_build()
{
    TOPDIR="$(pwd)"

    cd embeddedsw/lib/sw_apps/zynqmp_pmufw/src/

    CROSS="${HOME}/x-tools/microblazeel-xilinx-elf/bin/microblazeel-xilinx-elf-"
    CC=${CROSS}gcc
    AR=${CROSS}ar
    OBJCOPY=${CROSS}objcopy
    CFLAGS+=" -Os -flto -ffat-lto-objects"

    case ${BOARD_CONFIG} in
	kria|k26) CFLAGS+=" -DK26_SOM" ;;
	"") ;;
	*)  usage_exit 1 "Unknown config '${BOARD_CONFIG}'" ;;
    esac

    make COMPILER="${CC}" ARCHIVER="${AR}" CC="${CC}" CFLAGS="${CFLAGS}"

    cp executable.elf "${TOPDIR}"/pmufw.elf
    ${OBJCOPY} -O binary "${TOPDIR}"/pmufw.elf "${TOPDIR}"/pmufw.bin
}

pmufw_clean()
{
    make -C embeddedsw/lib/sw_apps/zynqmp_pmufw/src/ clean
    rm -f pmufw.elf pmufw.bin
}

BOARD_CONFIG=""
while getopts "hc:" FLAG; do
    case ${FLAG} in
	c)  BOARD_CONFIG="${OPTARG}" ;;
	h)  usage_exit 0 ;;
	\?) usage_exit 255 ;;
    esac
done
shift $((OPTIND-1))

[ $# -ge 1 ] || usage_exit 255 "SUBCMD not passed"

case "${1}" in
    toolchain)    build_toolchain;;
    pmufw-build)  pmufw_build;;
    pmufw-clean)  pmufw_clean;;
    *)            usage_exit 255 "Unknown subcommand '${1}'"
esac
