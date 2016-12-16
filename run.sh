#!/bin/bash

export VERSION="0.5.0"
export ATLAS_TOKEN="qyToIsMKMP9P0w.atlasv1.MiyPtcThL0y4Fwk53lFri83nOEt1rUDSQNW2CxFbxJtFd7llvllpqSL176pTkeFVfiE"

LINK=`readlink -f $0`
BASE=`dirname $LINK`

cd $BASE

# Disable IPv6 or the VMware builder won't be able to load the Kick Start configuration.
sudo sysctl net.ipv6.conf.all.disable_ipv6=1

# Start the required services.
sudo systemctl restart docker.service
sudo systemctl restart vmtoolsd.service
sudo systemctl restart vboxdrv.service
sudo systemctl restart libvirtd.service
sudo systemctl restart vmware.service vmware-USBArbitrator.service vmware-workstation-server.service

# Validate the templates before building.
packer validate magma.json && packer validate magma-centos6.json && packer validate magma-centos7.json
if [[ $? != 0 ]]; then
  printf "\a"; sleep 1; printf "\a"; sleep 1; printf "\a"
  tput setaf 1; tput bold; printf "\n\npacker templates failed to validate...\n\n"; tput sgr0
  exit 1
fi

# Build the boxes.
packer build -parallel=false magma-centos7.json
if [[ $? != 0 ]]; then
  printf "\a"; sleep 1; printf "\a"; sleep 1; printf "\a"
  tput setaf 1; tput bold; printf "\n\nmagma-centos7 images failed to build properly...\n\n"; tput sgr0
  rm -rf packer_cache/
  exit 1
else
  sleep 120
fi

packer build -parallel=false magma-centos6.json
if [[ $? != 0 ]]; then
  printf "\a"; sleep 1; printf "\a"; sleep 1; printf "\a"
  tput setaf 1; tput bold; printf "\n\nmagma-centos6 images failed to build properly...\n\n"; tput sgr0
  rm -rf packer_cache/
  exit 1
else
  sleep 120
fi

packer build -parallel=false magma.json
if [[ $? != 0 ]]; then
  printf "\a"; sleep 1; printf "\a"; sleep 1; printf "\a"
  tput setaf 1; tput bold; printf "\n\nmagma images failed to build properly...\n\n"; tput sgr0
  rm -rf packer_cache/
  exit 1
else
  sleep 120
fi

# Cleanup the artifacts.
# rm -rf xpti.dat compreg.dat VBoxSVC.log VirtualBox.xml VirtualBox.xml-prev packer_cache/
rm -rf packer_cache/

# Upload to the website.
#pscp -i ~/Data/Putty/root-virtual.lavabit.com.priv.ppk magma-centos-*-0.*.box root@osheana.virtual.lavabit.com:/var/www/html/downloads/
