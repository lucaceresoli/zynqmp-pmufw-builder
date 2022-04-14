#!/bin/bash

# SPDX-License-Identifier: Unlicense
# This is free and unencumbered software released into the public domain

set -e
set -u

usage()
{
    echo "Usage: $(basename $0) SUBCMD"
    echo "    SUBCMD can be:"
    echo "        - toolchain     install crosstool-NG locally and build toolchain"
    echo "        - pmufw-patch   patch the PMUFW sources to load cfg object (DEPRECATED)"
    echo "        - pmufw-build   build the PMUFW"
}

usage_exit() # message
{
    (
	echo "$1"
	echo
	usage
	exit 255
    ) >&2
}

[ $# -ge 1 ] || usage_exit "SUBCMD not passed"

build_toolchain()
{
    cp ct-ng.defconfig crosstool-ng/.config

    cd crosstool-ng/
    ./bootstrap
    ./configure --enable-local
    make
    yes "" | ./ct-ng oldconfig
    ./ct-ng build
}

pmufw_patch()
{
    patch -f -p1 --directory=embeddedsw <0001-Load-XPm_ConfigObject-at-boot.patch || \
	    echo "NOTE: this patch has probably already been applied, skipping it"

    sed 's!"pm_defs.h"!"../../../sw_services/xilpm/src/common/pm_defs.h"!' \
	    pm_cfg_obj.c > embeddedsw/lib/sw_apps/zynqmp_pmufw/src/pm_cfg_obj.c
}

pmufw_build()
{
    TOPDIR="$(pwd)"

    cd embeddedsw/lib/sw_apps/zynqmp_pmufw/src/

    BSP_DIR="../misc/zynqmp_pmufw_bsp"
    BSP_TARGETS_DIR="${BSP_DIR}/psu_pmu_0/libsrc"
    BSP_TARGETS_LIBDIR="${BSP_DIR}/psu_pmu_0/lib"
    BSP_LIBXIL="${BSP_TARGETS_LIBDIR}/libxil.a"

    CROSS="${HOME}/x-tools/microblazeel-xilinx-elf/bin/microblazeel-xilinx-elf-"
    CC=${CROSS}gcc
    AR=${CROSS}ar
    AS=${CROSS}as
    OBJCOPY=${CROSS}objcopy
    CFLAGS="-Wno-stringop-overflow -mlittle-endian -mxl-barrel-shift -mxl-pattern-compare -mno-xl-reorder -mcpu=v9.2 -mxl-soft-mul -mxl-soft-div -Os -flto -ffat-lto-objects"

    ../misc/copy_bsp.sh

    # Disable barrel shifter self test (unknown opcodes bsifi/bsefi in gcc 11.2.0 / crosstool-NG 1.24.0.500_584e57e)
    sed -e 's|#define XPAR_MICROBLAZE_USE_BARREL 1|#define XPAR_MICROBLAZE_USE_BARREL 0|' -i ../misc/zynqmp_pmufw_bsp/psu_pmu_0/include/xparameters.h

    # Fix xilfpga to include the zynqmp backend. Without this the build
    # succeeds but FPGA configuration will be silently ignored by the
    # resulting PMUFW.
    # From: https://github.com/Xilinx/meta-xilinx/commit/2c98fa11ccf33b6d9a550bebf50d2a2a876f9afb
    if ! [ -f ../misc/zynqmp_pmufw_bsp/psu_pmu_0/libsrc/xilfpga/src/xilfpga_pcap.c ] && \
         [ -f ../misc/zynqmp_pmufw_bsp/psu_pmu_0/libsrc/xilfpga/src/interface/zynqmp/xilfpga_pcap.c ];
    then
	echo "Applying xilfpga zynqmp workaround"
	cp ../misc/zynqmp_pmufw_bsp/psu_pmu_0/libsrc/xilfpga/src/interface/zynqmp/* \
	   ../misc/zynqmp_pmufw_bsp/psu_pmu_0/libsrc/xilfpga/src/
    fi

    # the Makefile in ${S}/../misc/Makefile, does not handle CC, AR, AS, etc
    # properly. So do its job manually. Preparing the includes first, then libs.
    for i in $(ls ${BSP_TARGETS_DIR}/*/src/Makefile); do
        make -C $(dirname $i) \
             CC="${CC}" \
             AR="${AR}" \
             AS="${AS}" \
             COMPILER="${CC}" \
             COMPILER_FLAGS="-O2 -c" \
             EXTRA_COMPILER_FLAGS="-g -Wall -Wextra -Os -flto -ffat-lto-objects" \
             ARCHIVER="${AR}" \
             CFLAGS="${CFLAGS}" \
             include libs
    done

    # Emulate the final archiving step by moving all .o's into libxil.a
    find ${BSP_TARGETS_LIBDIR} -type f -name "*.o" -exec ${AR} -r ${BSP_LIBXIL} {} \;

    make CC="${CC}" CC_FLAGS="-MMD -MP" CFLAGS="${CFLAGS}"

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

case "${1}" in
    toolchain)    build_toolchain;;
    pmufw-patch)  pmufw_patch;;
    pmufw-build)  pmufw_build;;
    *)            usage_exit "Unknown subcommand '${1}'"
esac
