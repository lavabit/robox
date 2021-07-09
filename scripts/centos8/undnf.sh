#!/bin/bash

sed -i -e "s/^baseurl/#baseurl/g" /etc/yum.repos.d/CentOS-Linux-Base.repo
sed -i -e "s/^#mirrorlist/mirrorlist/g" /etc/yum.repos.d/CentOS-Linux-Base.repo

sed -i -e "s/^baseurl/#baseurl/g" /etc/yum.repos.d/CentOS-Linux-AppStream.repo
sed -i -e "s/^#mirrorlist/mirrorlist/g" /etc/yum.repos.d/CentOS-Linux-AppStream.repo

sed -i -e "s/^baseurl/#baseurl/g" /etc/yum.repos.d/CentOS-Linux-PowerTools.repo
sed -i -e "s/^#mirrorlist/mirrorlist/g" /etc/yum.repos.d/CentOS-Linux-PowerTools.repo

sed -i -e "s/^baseurl/#baseurl/g" /etc/yum.repos.d/CentOS-Linux-Extras.repo
sed -i -e "s/^#mirrorlist/mirrorlist/g" /etc/yum.repos.d/CentOS-Linux-Extras.repo

sed -i -e "s/^baseurl/#baseurl/g" /etc/yum.repos.d/CentOS-Linux-centosplus.repo
sed -i -e "s/^#mirrorlist/mirrorlist/g" /etc/yum.repos.d/CentOS-Linux-centosplus.repo

sed -i -e "s/^baseurl/#baseurl/g" /etc/yum.repos.d/CentOS-Linux-Base.repo
sed -i -e "s/^#mirrorlist/mirrorlist/g" /etc/yum.repos.d/CentOS-Linux-Base.repo

sed -i -e "s/^baseurl/#baseurl/g" /etc/yum.repos.d/epel.repo
sed -i -e "s/^#mirrorlist/mirrorlist/g" /etc/yum.repos.d/epel.repo
