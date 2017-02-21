#!/bin/bash

export VERSION="0.5.7"
export DOCKER_USER="ladar"
export DOCKER_EMAIL="ladar@lavabitllc.com"
export DOCKER_PASSWORD="Fs2q5aGWNp6h^^N7qfhH"
export ATLAS_TOKEN="qyToIsMKMP9P0w.atlasv1.MiyPtcThL0y4Fwk53lFri83nOEt1rUDSQNW2CxFbxJtFd7llvllpqSL176pTkeFVfiE"

LINK=`readlink -f $0`
BASE=`dirname $LINK`

cd $BASE

# Disable IPv6 or the VMware builder won't be able to load the Kick Start configuration.
sudo sysctl net.ipv6.conf.all.disable_ipv6=1

# Start the required services.
sudo systemctl restart vmtoolsd.service
sudo systemctl restart vboxdrv.service
sudo systemctl restart libvirtd.service
sudo systemctl restart docker-latest.service
sudo systemctl restart vmware.service vmware-USBArbitrator.service vmware-workstation-server.service

# Validate the templates before building.
validate() {
  packer validate $1.json
  if [[ $? != 0 ]]; then
    printf "\a"; sleep 1; printf "\a"; sleep 1; printf "\a"
    tput setaf 1; tput bold; printf "\n\nthe $1 packer template failed to validate...\n\n"; tput sgr0
    exit 1
  fi
}

# Build the boxes and cleanup the packer cache after each run.
build() {
  packer build -parallel=false $1.json
  if [[ $? != 0 ]]; then
    printf "\a"; sleep 1; printf "\a"; sleep 1; printf "\a"
    tput setaf 1; tput bold; printf "\n\n$1 images failed to build properly...\n\n"; tput sgr0
    rm -rf packer_cache/
    exit 1
  else
    rm -rf packer_cache/
    sleep 120
  fi
}

validate magma
validate magma-centos6
validate magma-centos7
validate magma-docker
validate magma-vmware
validate magma-libvirt
validate magma-virtualbox

build magma
build magma-centos6
build magma-centos7
#build magma-docker
build magma-vmware
build magma-libvirt
build magma-virtualbox

# Upload to the website.
#pscp -i ~/Data/Putty/root-virtual.lavabit.com.priv.ppk magma-centos-*-0.*.box root@osheana.virtual.lavabit.com:/var/www/html/downloads/
