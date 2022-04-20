#!/bin/bash -eux

# Tweak the build script so it excludes the floppy.ko from the compressed RAM image.
sed -i 's/copy_modules_dir kernel\/drivers\/block/copy_modules_dir kernel\/drivers\/block floppy.ko/g' \
  /usr/share/initramfs-tools/hook-functions 

# Rebuild the compressed RAM images for all of the installed kernels.
update-initramfs -t -u -k all

# Check the image to ensure the floppy module is actually gone.
if [ "$(lsinitramfs /boot/initrd.img-$(uname -r) | grep floppy.ko | wc -l)" != 0 ]; then
  [ "`which tput 2> /dev/null`" != "" ] && [ -n "$TERM" ] && tput setaf 1
  echo -e "\nUnable to remove the floppy module from the compressed kernel image.\n" >&2
  [ "`which tput 2> /dev/null`" != "" ] && [ -n "$TERM" ] && tput sgr0
  exit 1
fi