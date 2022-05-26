#!/bin/bash

(umount /dev/cdrom && eject /dev/cdrom) || printf "\nThe RHEL cdrom isn't mounted.\n"

# If Parallels has mounted the user home directory, don't remove it.
if [ -d /media/psf/Home/ ]; then
  umount /media/psf/Home/
fi

if [ -d /media/BaseOS/ ]; then
  rm --force --recursive /media/BaseOS/
fi

if [ -d /media/AppStream/ ]; then
  rm --force --recursive /media/AppStream/
fi

if [ -f /etc/yum.repos.d/media.repo ]; then
  rm --force /etc/yum.repos.d/media.repo
fi

# sed -i -e "s/^baseurl/#baseurl/g" /etc/yum.repos.d/epel.repo
# sed -i -e "s/^#mirrorlist/mirrorlist/g" /etc/yum.repos.d/epel.repo
# sed -i -e "s/https:\/\/mirrors.edge.kernel.org\/fedora-epel\//http:\/\/download.fedoraproject.org\/pub\/epel\//g" /etc/yum.repos.d/epel.repo
