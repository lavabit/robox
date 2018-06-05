#!/bin/bash -eux

if [[ `id --user` != 0 ]]; then
  tput setaf 1; printf "\nError. Not running with root permissions.\n\n"; tput sgr0
  exit 2
fi

# Cross Platform Script Directory
pushd `dirname $0` > /dev/null
SCRIPT_PATH=`pwd -P`
popd > /dev/null
cd $SCRIPT_PATH

if [ -f $SCRIPT_PATH/../../.credentialsrc ]; then
  source $SCRIPT_PATH/../../.credentialsrc
else
  tput setaf 1; printf "\nError. The credentials file is missing.\n\n"; tput sgr0
  exit 2
fi

if [ -z ${VMWARE_WORKSTATION} ]; then
  tput setaf 1; printf "\nError. The VMware serial number is missing. Add it to the credentials file.\n\n"; tput sgr0
  exit 2
fi

# Update
yum --assumeyes --enablerepo=epel --enablerepo=centos-qemu-ev --enablerepo=virtualbox update

# Vagrant
yum --assumeyes update vagrant_2.1.1_x86_64.rpm

# Packer
unzip -o packer_1.2.4_linux_amd64.zip -d /usr/local/bin/

# VMware Workstation
bash VMware-Workstation-Full-12.5.9-7535481.x86_64.bundle --console --required --eulas-agreed --set-setting vmware-workstation serialNumber "${VMWARE_WORKSTATION}"
