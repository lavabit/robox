#!/bin/bash

sed -i -e "s/^baseurl/#baseurl/g" /etc/yum.repos.d/CentOS-Base.repo
sed -i -e "s/^#mirrorlist/mirrorlist/g" /etc/yum.repos.d/CentOS-Base.repo

sed -i -e "s/^baseurl/#baseurl/g" /etc/yum.repos.d/CentOS-AppStream.repo
sed -i -e "s/^#mirrorlist/mirrorlist/g" /etc/yum.repos.d/CentOS-AppStream.repo

sed -i -e "s/^baseurl/#baseurl/g" /etc/yum.repos.d/CentOS-PowerTools.repo
sed -i -e "s/^#mirrorlist/mirrorlist/g" /etc/yum.repos.d/CentOS-PowerTools.repo

sed -i -e "s/^baseurl/#baseurl/g" /etc/yum.repos.d/CentOS-Extras.repo
sed -i -e "s/^#mirrorlist/mirrorlist/g" /etc/yum.repos.d/CentOS-Extras.repo

sed -i -e "s/^baseurl/#baseurl/g" /etc/yum.repos.d/CentOS-centosplus.repo
sed -i -e "s/^#mirrorlist/mirrorlist/g" /etc/yum.repos.d/CentOS-centosplus.repo

sed -i -e "s/^baseurl/#baseurl/g" /etc/yum.repos.d/CentOS-Base.repo
sed -i -e "s/^#mirrorlist/mirrorlist/g" /etc/yum.repos.d/CentOS-Base.repo

sed -i -e "s/^baseurl/#baseurl/g" /etc/yum.repos.d/epel.repo
sed -i -e "s/^#mirrorlist/mirrorlist/g" /etc/yum.repos.d/epel.repo
