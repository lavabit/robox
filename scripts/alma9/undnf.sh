#!/bin/bash

# Alma Repo Setup
sed -i -e "s/^baseurl/#baseurl/g" /etc/yum.repos.d/almalinux-baseos.repo
sed -i -e "s/^#mirrorlist/mirrorlist/g" /etc/yum.repos.d/almalinux-baseos.repo

sed -i -e "s/^baseurl/#baseurl/g" /etc/yum.repos.d/almalinux-appstream.repo
sed -i -e "s/^#mirrorlist/mirrorlist/g" /etc/yum.repos.d/almalinux-appstream.repo

sed -i -e "s/^baseurl/#baseurl/g" /etc/yum.repos.d/almalinux-extras.repo
sed -i -e "s/^#mirrorlist/mirrorlist/g" /etc/yum.repos.d/almalinux-extras.repo

sed -i -e "s/^baseurl/#baseurl/g" /etc/yum.repos.d/almalinux-plus.repo
sed -i -e "s/^#mirrorlist/mirrorlist/g" /etc/yum.repos.d/almalinux-plus.repo
