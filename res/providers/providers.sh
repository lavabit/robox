#!/bin/bash -eux

export HUMAN="ladar"

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

function provide-libvirt() {
  # Repo setup.
  yum --assumeyes --enablerepo=extras install epel-release centos-release-qemu-ev

  # Libvirt Install
  yum --assumeyes --enablerepo=epel --enablerepo=centos-qemu-ev install libvirt libvirt-client libvirt-daemon libvirt-daemon-config-network libvirt-daemon-config-nwfilter libvirt-daemon-driver-interface libvirt-daemon-driver-network libvirt-daemon-driver-nodedev libvirt-daemon-driver-nwfilter libvirt-daemon-driver-qemu libvirt-daemon-driver-secret libvirt-daemon-driver-storage libvirt-daemon-kvm qemu qemu-common qemu-img qemu-kvm qemu-kvm-common qemu-kvm-tools qemu-system-x86 qemu-user

  # Setup the Libvirt, QEMU and KVM Groups
  usermod -aG kvm root
  usermod -aG qemu root
  usermod -aG libvirt root
  usermod -aG kvm $HUMAN
  usermod -aG qemu $HUMAN
  usermod -aG libvirt $HUMAN

  # Disable Libvirt Automatic Startup
  systemctl disable libvirtd.service
  systemctl disable libvirt-guests.service
}

function provide-lxc() {
  # LXC install (Optional)
  yum --assumeyes --enablerepo=epel install lxc lua-lxc lxc-libs libvirt-daemon-driver-lxc libvirt-daemon-lxc

  # Disable LXC Automatic Startup
  systemctl disable lxc.service
}

function provide-virtmanager() {
  # Remove Viewer / Virt Manager Client Install (Optional)
  yum --assumeyes install virt-manager virt-manager-common gvnc libgvnc gtk-vnc2 spice-glib spice-gtk3 libspice-client-glib libvirt-glib libvirt-gconfig libvirt-gobject libvirt-python
}

function provide-vmware() {
  # VMware Workstation Install
  chmod +x VMware-Workstation-Full-12.5.9-7535481.x86_64.bundle
  bash VMware-Workstation-Full-12.5.9-7535481.x86_64.bundle --console --required --eulas-agreed --set-setting vmware-workstation serialNumber "${VMWARE_WORKSTATION}"

  # Disable VMWare Automatic Startup
  systemctl disable vmware.service
  systemctl disable vmware-USBArbitrator.service
  systemctl disable vmware-workstation-server.service

  # Setup the Virtual Interfaces as Trusted
  firewall-cmd --permanent --zone=trusted --add-interface=vmnet1
  firewall-cmd --permanent --zone=trusted --add-interface=vmnet8
}

function provide-vbox() {
  # Virtual Box Repo
  cp virtualbox.repo /etc/yum.repos.d/virtualbox.repo
  chown root:root /etc/yum.repos.d/virtualbox.repo
  chcon system_u:object_r:system_conf_t:s0 /etc/yum.repos.d/virtualbox.repo

  cp virtualbox.pem /etc/pki/rpm-gpg/RPM-GPG-KEY-Oracle-Vbox
  chown root:root /etc/pki/rpm-gpg/RPM-GPG-KEY-Oracle-Vbox
  chcon system_u:object_r:cert_t:s0 /etc/pki/rpm-gpg/RPM-GPG-KEY-Oracle-Vbox

  # Virtual Box Install
  yum --assumeyes --enablerepo=virtualbox install VirtualBox-5.2.x86_64

  # Virtual Box Extensions
  VBOXVER=`VBoxManage --version | awk -F'r' '{print $1}'`
  VBOXEXT="Oracle_VM_VirtualBox_Extension_Pack-${VBOXVER}.vbox-extpack"
  VBOXEXTURL="http://download.virtualbox.org/virtualbox/${VBOXVER}/${VBOXEXT}"

  # Download the extension pack.
  curl "${VBOXEXTURL}" > "${VBOXEXT}"

  # Calculate the license hash.
  VBOXACCEPT=`tar --extract --to-stdout --file="${VBOXEXT}" ./ExtPack-license.txt | sha256sum | awk -F' ' '{print $1}'`

  # Uncomment this line to install the VirtualBox extensions.
  VBoxManage extpack install --accept-license="${VBOXACCEPT}" "${VBOXEXT}"

  # Cleanup the downloaded file.
  rm --force "${VBOXEXT}"

  # Disable Virtual Box Automatic Startup
  systemctl disable vboxautostart-service.service
  systemctl disable vboxballoonctrl-service.service
  systemctl disable vboxdrv.service
  systemctl disable vboxweb-service.service

  # Add the key users to the vboxusers group.
  usermod -aG vboxusers root
  usermod -aG vboxusers $HUMAN

  # Setup the Virtual Interfaces as Trusted
  firewall-cmd --permanent --zone=trusted --add-interface=vibr0
}

function provide-docker() {
  # Docker Install
  yum --assumeyes install docker docker-common docker-selinux docker-logrotate
  yum --assumeyes install docker-latest docker-latest-logrotate docker-latest-v1.10-migrator
  yum --assumeyes install python-docker-py python-docker-scripts python-dockerfile-parse

  # Setup Docker Latest as the Default
  sed -i -e "s/#DOCKERBINARY=\/usr\/bin\/docker-latest/DOCKERBINARY=\/usr\/bin\/docker-latest/g" /etc/sysconfig/docker

  # Setup the Docker Group
  groupadd docker
  usermod -aG docker root
  usermod -aG docker $HUMAN

  # Disable Docker Automatic Startup
  systemctl disable docker-cleanup.service
  systemctl disable docker-latest-storage-setup.service
  systemctl disable docker-latest.service
  systemctl disable docker-storage-setup.service
  systemctl disable docker.service
  systemctl disable docker-cleanup.timer

  # Setup the Virtual Interfaces as Trusted
  firewall-cmd --permanent --zone=trusted --add-interface=docker0
}

function provide-vagrant() {
  # Vagrant
  yum --assumeyes install vagrant_2.1.1_x86_64.rpm

  # Vagrant Libvirt Plugin
  vagrant plugin install vagrant-libvirt
}

function provide-packer() {
  # Packer
  unzip -o packer_1.2.4_linux_amd64.zip -d /usr/local/bin/
  chown root:root /usr/local/bin/packer
  chcon unconfined_u:object_r:bin_t:s0 /usr/local/bin/packer
}
