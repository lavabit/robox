#!/bin/bash

sed -i -e "s/^#baseurl/baseurl/g" /etc/yum.repos.d/CentOS-Base.repo
sed -i -e "s/^mirrorlist/#mirrorlist/g" /etc/yum.repos.d/CentOS-Base.repo
sed -i -e "s/http:\/\/mirror.centos.org\/centos\//https:\/\/mirrors.edge.kernel.org\/centos\//g" /etc/yum.repos.d/CentOS-Base.repo

rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
yum --quiet --assumeyes --enablerepo=extras install epel-release

sed -i -e "s/^#baseurl/baseurl/g" /etc/yum.repos.d/epel.repo 
sed -i -e "s/^mirrorlist/#mirrorlist/g" /etc/yum.repos.d/epel.repo 
sed -i -e "s/http:\/\/download.fedoraproject.org\/pub\/epel\//https:\/\/mirrors.edge.kernel.org\/fedora-epel\//g" /etc/yum.repos.d/epel.repo 

rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-7
