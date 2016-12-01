#!/bin/bash

LINK=`readlink -f $0`
BASE=`dirname $LINK`

cd $BASE
export VBOX_USER_HOME="$BASE"
#export ATLAS_TOKEN="qyToIsMKMP9P0w.atlasv1.MiyPtcThL0y4Fwk53lFri83nOEt1rUDSQNW2CxFbxJtFd7llvllpqSL176pTkeFVfiE"

#sudo /etc/init.d/vmware start
sudo systemctl start vmtoolsd.service
sudo systemctl start libvirtd.service
sudo systemctl start vboxdrv.service

sudo /etc/init.d/vmware start
sudo /etc/init.d/vmware-USBArbitrator
sudo /etc/init.d/vmware-workstation-server start

packer build -parallel=false magma.json
packer build -parallel=false magma-centos6.json
packer build -parallel=false magma-centos7.json
#pscp -i ~/Data/Putty/root-virtual.lavabit.com.priv.ppk magma-centos-*-0.*.box root@osheana.virtual.lavabit.com:/var/www/html/downloads/

