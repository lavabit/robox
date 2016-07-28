#!/bin/bash

LINK=`readlink -f $0`
BASE=`dirname $LINK`

cd $BASE
export VBOX_USER_HOME="$BASE"

#sudo /etc/init.d/vmware start
#sudo systemctl start vmtoolsd.service
#sudo systemctl start libvirtd.service
#sudo systemctl start vboxdrv.service

sudo /etc/init.d/vmware start
sudo /etc/init.d/vmware-USBArbitrator
sudo /etc/init.d/vmware-workstation-server start

packer build -parallel=false template.json
pscp -i ~/Data/Putty/root-virtual.lavabit.com.priv.ppk magma-centos-*-0.*.box root@osheana.virtual.lavabit.com:/var/www/html/downloads/

