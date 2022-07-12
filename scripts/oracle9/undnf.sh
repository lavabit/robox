#!/bin/bash

# Alma Repo Setup
sed -i -e "s/^baseurl/#baseurl/g" /etc/yum.repos.d/orcle-linux-ol9.repo
sed -i -e "s/^#mirrorlist/mirrorlist/g" /etc/yum.repos.d/orcle-linux-ol9.repo

sed -i -e "s/^baseurl/#baseurl/g" /etc/yum.repos.d/uek-ol9.repo
sed -i -e "s/^#mirrorlist/mirrorlist/g" /etc/yum.repos.d/uek-ol9.repo

sed -i -e "s/^baseurl/#baseurl/g" /etc/yum.repos.d/virt-ol9.repo
sed -i -e "s/^#mirrorlist/mirrorlist/g" /etc/yum.repos.d/virt-ol9.repo

sed -i -e "s/^baseurl/#baseurl/g" /etc/yum.repos.d/oracle-epel-ol9.repo
sed -i -e "s/^#mirrorlist/mirrorlist/g" /etc/yum.repos.d/oracle-epel-ol9.repo

