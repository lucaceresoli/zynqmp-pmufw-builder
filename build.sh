#!/bin/bash

set -e
set -u

usage()
{
    echo "Usage: $(basename $0) SUBCMD"
    echo "    SUBCMD can be:"
    echo "        - toolchain     install crosstool-NG locally and build toolchain"
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

case "${1}" in
    toolchain)    build_toolchain;;
    *)            usage_exit "Unknown subcommand '${1}'"
esac
