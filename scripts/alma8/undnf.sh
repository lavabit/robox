#!/bin/bash

sed -i -e "s/^baseurl/# baseurl/g" /etc/yum.repos.d/almalinux.repo
sed -i -e "s/^#mirrorlist/mirrorlist/g" /etc/yum.repos.d/almalinux.repo

sed -i -e "s/^baseurl/# baseurl/g" /etc/yum.repos.d/almalinux-powertools.repo
sed -i -e "s/^#mirrorlist/mirrorlist/g" /etc/yum.repos.d/almalinux-powertools.repo

sed -i -e "s/^baseurl/#baseurl/g" /etc/yum.repos.d/epel.repo
sed -i -e "s/^#mirrorlist/mirrorlist/g" /etc/yum.repos.d/epel.repo
