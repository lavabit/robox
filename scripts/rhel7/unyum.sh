#!/bin/bash

rm --force /etc/yum.repos.d/media.repo

sed -i -e "s/^baseurl/#baseurl/g" /etc/yum.repos.d/epel.repo
sed -i -e "s/^#mirrorlist/mirrorlist/g" /etc/yum.repos.d/epel.repo
sed -i -e "s/https:\/\/mirrors.kernel.org\/fedora-epel\//http:\/\/download.fedoraproject.org\/pub\/epel\//g" /etc/yum.repos.d/epel.repo
