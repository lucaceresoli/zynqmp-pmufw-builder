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

3. Optionally you can overwrite `pm_cfg_obj.c` with the configuration
   object for your design.

4. Then patch the PMUFM sources so it loads the a hard-coded configuraton
   object from `pm_cfg_obj.c`:

       ./build.sh pmufw-patch

5. Build it:

       ./build.sh pmufw-build

   The PMU firmware will be called `pmufw.bin` in the current directory.

Enjoy!
