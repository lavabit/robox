#!/bin/bash

VERSION="0.3.2"

LINK=`readlink -f $0`
BASE=`dirname $LINK`

cd $BASE
#export VBOX_USER_HOME="$BASE"
export ATLAS_TOKEN="qyToIsMKMP9P0w.atlasv1.MiyPtcThL0y4Fwk53lFri83nOEt1rUDSQNW2CxFbxJtFd7llvllpqSL176pTkeFVfiE"

# Disable IPv6 or the VMware builder won't be able to load the Kick Start configuration.
sudo sysctl net.ipv6.conf.all.disable_ipv6=1

# Start the required services.
sudo systemctl start vmtoolsd.service
sudo systemctl start libvirtd.service
sudo systemctl start vboxdrv.service
sudo systemctl start docker.service

sudo /etc/init.d/vmware start
sudo /etc/init.d/vmware-USBArbitrator
sudo /etc/init.d/vmware-workstation-server start

# Build the boxes.
packer build -var "box_version=$VERSION" -parallel=false magma-centos7.json
if [[ $? != 0 ]]; then
  rm -rf packer_cache/                                                      
  exit 1
else 
  sleep 60
fi
packer build -var "box_version=$VERSION" -parallel=false magma-centos6.json
if [[ $? != 0 ]]; then
  rm -rf packer_cache/                                                      
  exit 1
else
  sleep 60
fi
packer build -var "box_version=$VERSION" -parallel=false magma.json
if [[ $? != 0 ]]; then
  rm -rf packer_cache/                                                      
  exit 1
fi

# Cleanup the artifacts.
# rm -rf xpti.dat compreg.dat VBoxSVC.log VirtualBox.xml VirtualBox.xml-prev packer_cache/ 
rm -rf packer_cache/ 

# Upload to the website.
#pscp -i ~/Data/Putty/root-virtual.lavabit.com.priv.ppk magma-centos-*-0.*.box root@osheana.virtual.lavabit.com:/var/www/html/downloads/

