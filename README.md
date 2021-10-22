zynqmp-pmufw-builder
====================

This is a simple script to build a PMU firmware for the Xilinx ZynqMP
System-on-Chip.

It design goals are to:

* be simple to use: just type a few commands to have a PMU firmware
  ready
* be easy to understand and modify to your needs
* have minimal dependencies: only crosstool-NG and the PMU firmware
  source code are needed



Usage
=====

1. Get the source code:

       git clone --recursive https://github.com/lucaceresoli/zynqmp-pmufw-builder.git
       cd zynqmp-pmufw-builder

2. Generate a suitable microblaze toolchain (this is normally needed
   only once):

       ./build.sh toolchain

   At the end a toolchain will be available in
   `~/x-tools/microblazeel-unknown-elf/`.

3. Build it:

       ./build.sh pmufw-build

   The PMU firmware will be called `pmufw.bin` in the current directory.

Enjoy!

Hard-coded configuration object (deprecated, unsupported)
---------------------------------------------------------

In the past, in order to boot with U-Boot SPL, you needed a tweak to embed
a PMU configuration object in the PMUFW. This limitation does no longer
exist since U-Boot 2019.10, so it is recommended to build the PMUFW without
any tweak and let U-Boot SPL load the configuration object at runtime. More
details in [this blog
post](https://lucaceresoli.net/zynqmp-uboot-spl-pmufw-cfg-load/).

For historical reference, here is how to apply the tweak. After step 2
above, add these steps:

1. Copy `pm_cfg_obj.c` with the configuration object for your design in the
   root directory (where `build.sh` is).

2. Patch the PMUFW sources so it loads the hard-coded configuraton object
   from `pm_cfg_obj.c`:

       ./build.sh pmufw-patch
