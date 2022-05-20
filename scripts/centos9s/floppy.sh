#!/bin/bash

printf 'blacklist floppy\n' > /etc/modprobe.d/floppy.conf
chcon system_u:object_r:modules_conf_t:s0 /etc/modprobe.d/floppy.conf
(rpm -q --qf="%{VERSION}-%{RELEASE}.%{ARCH}\n" --whatprovides kernel ; uname -r) | \
sort | uniq | while read KERNEL ; do 
  dracut -f "/boot/initramfs-${KERNEL}.img" "${KERNEL}" || exit 1
done

