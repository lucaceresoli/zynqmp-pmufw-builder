#!/bin/bash

set -e
set -u

usage()
{
    echo "Usage: $(basename $0) SUBCMD"
    echo "    SUBCMD can be:"
    echo "        - toolchain     install crosstool-NG locally and build toolchain"
    echo "        - pmufw-patch   patch the PMUFW sources to load cfg object"
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

case "${1}" in
    toolchain)    build_toolchain;;
    pmufw-patch)  pmufw_patch;;
    *)            usage_exit "Unknown subcommand '${1}'"
esac
