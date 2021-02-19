#!/bin/bash

rm --force /etc/yum.repos.d/media.repo
umount /dev/cdrom

# If Parallels has mounted the user home directory, don't remove it.
if [ -d /media/psf/Home/ ]; then
  umount /media/psf/Home/
fi

if [ -f /media/media.repo ]; then
  rm --force --recursive /media/*
fi

sed -i -e "s/^baseurl/#baseurl/g" /etc/yum.repos.d/epel.repo
sed -i -e "s/^#mirrorlist/mirrorlist/g" /etc/yum.repos.d/epel.repo
sed -i -e "s/https:\/\/mirrors.kernel.org\/fedora-epel\//http:\/\/download.fedoraproject.org\/pub\/epel\//g" /etc/yum.repos.d/epel.repo
