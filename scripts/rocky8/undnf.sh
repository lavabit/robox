#!/bin/bash

sed -i -e "s/^baseurl/#baseurl/g" /etc/yum.repos.d/Rocky-Base.repo
sed -i -e "s/^#mirrorlist/mirrorlist/g" /etc/yum.repos.d/Rocky-Base.repo

sed -i -e "s/^baseurl/#baseurl/g" /etc/yum.repos.d/Rocky-AppStream.repo
sed -i -e "s/^#mirrorlist/mirrorlist/g" /etc/yum.repos.d/Rocky-AppStream.repo

sed -i -e "s/^baseurl/#baseurl/g" /etc/yum.repos.d/Rocky-PowerTools.repo
sed -i -e "s/^#mirrorlist/mirrorlist/g" /etc/yum.repos.d/Rocky-PowerTools.repo

sed -i -e "s/^baseurl/#baseurl/g" /etc/yum.repos.d/Rocky-Extras.repo
sed -i -e "s/^#mirrorlist/mirrorlist/g" /etc/yum.repos.d/Rocky-Extras.repo

sed -i -e "s/^baseurl/#baseurl/g" /etc/yum.repos.d/Rocky-centosplus.repo
sed -i -e "s/^#mirrorlist/mirrorlist/g" /etc/yum.repos.d/Rocky-centosplus.repo

sed -i -e "s/^baseurl/#baseurl/g" /etc/yum.repos.d/Rocky-Base.repo
sed -i -e "s/^#mirrorlist/mirrorlist/g" /etc/yum.repos.d/Rocky-Base.repo

sed -i -e "s/^baseurl/#baseurl/g" /etc/yum.repos.d/epel.repo
sed -i -e "s/^#mirrorlist/mirrorlist/g" /etc/yum.repos.d/epel.repo
