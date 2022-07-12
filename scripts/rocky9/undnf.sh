#!/bin/bash

sed -i -e "s/^baseurl/#baseurl/g" /etc/yum.repos.d/rocky.repo
sed -i -e "s/^#mirrorlist/mirrorlist/g" /etc/yum.repos.d/rocky.repo

sed -i -e "s/^baseurl/#baseurl/g" /etc/yum.repos.d/rocky-extras.repo
sed -i -e "s/^#mirrorlist/mirrorlist/g" /etc/yum.repos.d/rocky-extras.repo

sed -i -e "s/^baseurl/#baseurl/g" /etc/yum.repos.d/rocky-devel.repo
sed -i -e "s/^#mirrorlist/mirrorlist/g" /etc/yum.repos.d/rocky-devel.repo

sed -i -e "s/^baseurl/#baseurl/g" /etc/yum.repos.d/rocky-addons.repo
sed -i -e "s/^#mirrorlist/mirrorlist/g" /etc/yum.repos.d/rocky-addons.repo

sed -i -e "s/^baseurl/#baseurl/g" /etc/yum.repos.d/epel.repo
sed -i -e "s/^#mirrorlist/mirrorlist/g" /etc/yum.repos.d/epel.repo
