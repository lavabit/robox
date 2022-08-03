#!/bin/bash

grep --quiet mirrorlist /etc/yum.repos.d/rocky.repo && \
sed -i -e "s/^baseurl/#baseurl/g" /etc/yum.repos.d/rocky.repo && \
sed -i -e "s/^#mirrorlist/mirrorlist/g" /etc/yum.repos.d/rocky.repo

grep --quiet mirrorlist /etc/yum.repos.d/rocky-extras.repo && \
sed -i -e "s/^baseurl/#baseurl/g" /etc/yum.repos.d/rocky-extras.repo && \
sed -i -e "s/^#mirrorlist/mirrorlist/g" /etc/yum.repos.d/rocky-extras.repo

grep --quiet mirrorlist /etc/yum.repos.d/rocky-devel.repo && \
sed -i -e "s/^baseurl/#baseurl/g" /etc/yum.repos.d/rocky-devel.repo && \
sed -i -e "s/^#mirrorlist/mirrorlist/g" /etc/yum.repos.d/rocky-devel.repo

grep --quiet mirrorlist /etc/yum.repos.d/rocky-addons.repo && \
sed -i -e "s/^baseurl/#baseurl/g" /etc/yum.repos.d/rocky-addons.repo && \
sed -i -e "s/^#mirrorlist/mirrorlist/g" /etc/yum.repos.d/rocky-addons.repo

grep --quiet mirrorlist /etc/yum.repos.d/epel.repo && \
sed -i -e "s/^baseurl/#baseurl/g" /etc/yum.repos.d/epel.repo && \
sed -i -e "s/^#mirrorlist/mirrorlist/g" /etc/yum.repos.d/epel.repo
