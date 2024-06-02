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
    CFLAGS+=" -Wno-stringop-overflow -mlittle-endian -mxl-barrel-shift -mxl-pattern-compare -mno-xl-reorder -mcpu=v9.2 -mxl-soft-mul -mxl-soft-div -Os -flto -ffat-lto-objects"

    case ${BOARD_CONFIG} in
	kria|k26) CFLAGS+=" -DK26_SOM" ;;
	"") ;;
	*)  usage_exit 1 "Unknown config '${BOARD_CONFIG}'" ;;
    esac

    # Disable barrel shifter self test (unknown opcodes bsifi/bsefi in gcc 11.2.0 / crosstool-NG 1.24.0.500_584e57e)
    sed -e 's|#define XPAR_MICROBLAZE_USE_BARREL 1|#define XPAR_MICROBLAZE_USE_BARREL 0|' -i ../misc/xparameters.h

    make COMPILER="${CC}" ARCHIVER="${AR}" CC="${CC}" CFLAGS="${CFLAGS}"

    ${OBJCOPY} -O binary executable.elf executable.bin
    cp executable.elf "${TOPDIR}"/pmufw.elf
    cp executable.bin "${TOPDIR}"/pmufw.bin

    # Sanity checks
    if ! [ -f ../misc/zynqmp_pmufw_bsp/psu_pmu_0/libsrc/xilfpga/src/xilfpga_pcap.o ]
    then
	(
	    echo "******************************************"
	    echo "*** xilfpga_pcap.o has not been built! ***"
	    echo "***    the generated PMUFW will not    ***"
	    echo "***       load an FPGA bitstream!      ***"
	    echo "******************************************"
	) >&2
	exit 255
    fi
}

pmufw_clean()
{
    make -C embeddedsw/lib/sw_apps/zynqmp_pmufw/src/ clean
    rm -f embeddedsw/lib/sw_apps/zynqmp_pmufw/src/executable.bin
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
