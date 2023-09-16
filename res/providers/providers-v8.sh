#!/bin/bash 

# The unprivileged user that will be running packer/using the boxes.
[ "${HUMAN}x" == "x" ] && export HUMAN="$(echo $SUDO_USER)"
[ "${HUMAN}x" == "x" ] && export HUMAN="$(logname)"
[ "${HUMAN}x" == "x" ] && export HUMAN="$(echo LOGNAME)"
[ "${HUMAN}x" == "x" ] && export HUMAN="$(echo USER)"

# Handle self referencing, sourcing etc.
if [[ $0 != $BASH_SOURCE ]]; then
  export CMD=$BASH_SOURCE
else
  export CMD=$0
fi

# Ensure a consistent working directory so relative paths work.
pushd `dirname $CMD` > /dev/null
BASE=`pwd -P`
popd > /dev/null
cd $BASE

function provide-limits() {

  # Find out how much RAM is installed, and what 50% would be in KB.
  TOTALMEM=`free -k | grep -E "^Mem:" | awk -F' ' '{print $2}'`
  HALFMEM=`echo $(($TOTALMEM/2))`

  # Increase the limits for our human user.
  printf "$HUMAN    soft    memlock    $HALFMEM\n" > /etc/security/limits.d/50-$HUMAN.conf
  printf "$HUMAN    hard    memlock    $HALFMEM\n" >> /etc/security/limits.d/50-$HUMAN.conf
  printf "$HUMAN    soft    nproc      65536\n" >> /etc/security/limits.d/50-$HUMAN.conf
  printf "$HUMAN    hard    nproc      65536\n" >> /etc/security/limits.d/50-$HUMAN.conf
  printf "$HUMAN    soft    nofile     1048576\n" >> /etc/security/limits.d/50-$HUMAN.conf
  printf "$HUMAN    hard    nofile     1048576\n" >> /etc/security/limits.d/50-$HUMAN.conf
  printf "$HUMAN    soft    stack      unlimited\n" >> /etc/security/limits.d/50-$HUMAN.conf
  printf "$HUMAN    hard    stack      unlimited\n" >> /etc/security/limits.d/50-$HUMAN.conf

  chcon "system_u:object_r:etc_t:s0" /etc/security/limits.d/50-$HUMAN.conf

  # Now do the same for the root user.
  printf "root      soft    memlock    $HALFMEM\n" > /etc/security/limits.d/50-root.conf
  printf "root      hard    memlock    $HALFMEM\n" >> /etc/security/limits.d/50-root.conf
  printf "root      soft    nproc      65536\n" >> /etc/security/limits.d/50-root.conf
  printf "root      hard    nproc      65536\n" >> /etc/security/limits.d/50-root.conf
  printf "root      soft    nofile     1048576\n" >> /etc/security/limits.d/50-root.conf
  printf "root      hard    nofile     1048576\n" >> /etc/security/limits.d/50-root.conf
  printf "root      soft    stack      unlimited\n" >> /etc/security/limits.d/50-root.conf
  printf "root      hard    stack      unlimited\n" >> /etc/security/limits.d/50-root.conf

  chcon "system_u:object_r:etc_t:s0" /etc/security/limits.d/50-root.conf
}

function provide-lxc() {
  # LXC install (Optional)
  dnf --assumeyes --enablerepo=epel install lxc lua-lxc lxc-libs \
   libvirt-daemon-driver-lxc libvirt-daemon-lxc

  # Disable LXC Automatic Startup
  systemctl disable lxc.service
}

function provide-virtmanager() {
  # Remove Viewer / Virt Manager Client Install (Optional)
  dnf --assumeyes install virt-manager virt-manager-common gvnc \
    gtk-vnc2 spice-glib spice-gtk3  libvirt-python \
    libvirt-glib libvirt-gconfig libvirt-gobject
}

function provide-libvirt() {
  # Repo setup.
  dnf --assumeyes --enablerepo=extras install epel-release

  # libvirt Install
  dnf --assumeyes --enablerepo=epel install \
    libvirt libvirt-client libvirt-daemon libvirt-daemon-config-network \
    libvirt-daemon-config-nwfilter libvirt-daemon-driver-interface \
    libvirt-daemon-driver-network libvirt-daemon-driver-nodedev \
    libvirt-daemon-driver-nwfilter libvirt-daemon-driver-qemu \
    libvirt-daemon-driver-secret libvirt-daemon-driver-storage \
    libvirt-daemon-driver-storage-core libvirt-daemon-driver-storage-scsi \
    libvirt-daemon-kvm libvirt-dbus libvirt-docs libvirt-libs libvirt-nss \
    python3-libvirt qemu-img qemu-kvm qemu-kvm-block-curl \
    qemu-kvm-block-ssh qemu-kvm-common qemu-kvm-core qemu-kvm-docs \
    qemu-kvm-hw-usbredir qemu-kvm-ui-opengl qemu-kvm-ui-spice

  # Setup the libvirt, QEMU and KVM Groups
  usermod -aG kvm root
  usermod -aG qemu root
  usermod -aG libvirt root
  usermod -aG kvm $HUMAN
  usermod -aG qemu $HUMAN
  usermod -aG libvirt $HUMAN

  # Disable libvirt Automatic Startup
  systemctl disable libvirtd.service
  systemctl disable libvirt-guests.service

  # Detect support the vhost_net kernel module and configure it to load automatically.
  export $(grep CONFIG_PCI_MSI= /boot/config-$(uname -r))
  export $(grep CONFIG_VHOST_NET= /boot/config-$(uname -r))

  if [[ "$CONFIG_PCI_MSI" =~ ^(m|y) ]] && [[ "$CONFIG_VHOST_NET" =~ ^(m|y) ]] && \
    [ -d /etc/modules-load.d/ ] && [ ! -f /etc/modules-load.d/10-vhost_net.conf ]; then
    printf "vhost_net\n" > "/etc/modules-load.d/10-vhost_net.conf"
    chown root:root "/etc/modules-load.d/10-vhost_net.conf"
    chmod 644 "/etc/modules-load.d/10-vhost_net.conf"
    chcon system_u:object_r:etc_t:s0 "/etc/modules-load.d/10-vhost_net.conf"
    modprobe vhost_net
  fi

  unset CONFIG_PCI_MSI
  unset CONFIG_VHOST_NET

  ln -s /usr/libexec/qemu-kvm /usr/bin/qemu-system-i386
  ln -s /usr/libexec/qemu-kvm /usr/bin/qemu-system-x86_64
   
  if [ -f /usr/bin/X ]; then
    provide-virtmanager
  fi
}

function provide-vmware() {

  # Ensure the VMWare Serial is Available
  if [ -z ${VMWARE_WORKSTATION} ]; then
    tput setaf 1; printf "\nError. The VMware serial number is missing. Add it to the credentials file.\n\n"; tput sgr0
    exit 2
  fi

  # Acquire the install bundle.
  if [ ! -f "$BASE/VMware-Workstation-Full-16.2.5-20904516.x86_64.bundle" ]; then
    curl --location --output "$BASE/VMware-Workstation-Full-16.2.5-20904516.x86_64.bundle" \
     "https://archive.org/download/vmware-workstation-17.0.0/VMware-Workstation-Full-16.2.5-20904516.x86_64.bundle"
  fi

  # Verify the installer bundle.
  (printf "3ee36946b15e3093fd032115f5b6e5dabf4081f54756d5e795b4534473ea53e7  VMware-Workstation-Full-16.2.5-20904516.x86_64.bundle\n" | sha256sum -c) || \
    { tput setaf 1 ; printf "\nError downloading the install bundle.\n\n" ; tput sgr0 ; exit 2 ; }

  # Acquire the FreeBSD / Darwin / Solaris guest tools.
  if [ ! -f "$BASE/VMware-Tools-10.1.15-other-6677369.tar.gz" ]; then
    curl --location --output "$BASE/VMware-Tools-10.1.15-other-6677369.tar.gz" \
     "https://archive.org/download/vmwaretools10.1.15other6677369.tar/VMware-Tools-10.1.15-other-6677369.tar.gz"
  fi

  # Verify the tools bundle.
  (printf "b0ae1ba296f6be60a49e748f0aac48b629a0612d98d2c7c5cff072b5f5bbdb2a  VMware-Tools-10.1.15-other-6677369.tar.gz\n" | sha256sum -c) || \
    { tput setaf 1 ; printf "\nError downloading the alternative operating system guest additions.\n\n" ; tput sgr0 ; exit 2 ; }

  # VMware Workstation Install
  chmod +x "$BASE/VMware-Workstation-Full-16.2.5-20904516.x86_64.bundle"
  printf "yes\n" | bash "$BASE/VMware-Workstation-Full-16.2.5-20904516.x86_64.bundle" --console \
    --required --eulas-agreed --set-setting vmware-workstation serialNumber "${VMWARE_WORKSTATION}"

  # Install the alternative operating system ISOs.
  tar --extract --gzip --to-stdout --file="$BASE/VMware-Tools-10.1.15-other-6677369.tar.gz" \
    "VMware-Tools-10.1.15-other-6677369/vmtools/darwin.iso" > "/usr/lib/vmware/isoimages/darwin.iso"
  chown root:root "/usr/lib/vmware/isoimages/darwin.iso"
  chmod 644 "/usr/lib/vmware/isoimages/darwin.iso"
  chcon unconfined_u:object_r:lib_t:s0 "/usr/lib/vmware/isoimages/darwin.iso"

  tar --extract --gzip --to-stdout --file="$BASE/VMware-Tools-10.1.15-other-6677369.tar.gz" \
    "VMware-Tools-10.1.15-other-6677369/vmtools/freebsd.iso" > "/usr/lib/vmware/isoimages/freebsd.iso"
  chown root:root "/usr/lib/vmware/isoimages/freebsd.iso"
  chmod 644 "/usr/lib/vmware/isoimages/freebsd.iso"
  chcon unconfined_u:object_r:lib_t:s0 "/usr/lib/vmware/isoimages/freebsd.iso"

  tar --extract --gzip --to-stdout --file="$BASE/VMware-Tools-10.1.15-other-6677369.tar.gz" \
    "VMware-Tools-10.1.15-other-6677369/vmtools/solaris.iso" > "/usr/lib/vmware/isoimages/solaris.iso"
  chown root:root "/usr/lib/vmware/isoimages/solaris.iso"
  chmod 644 "/usr/lib/vmware/isoimages/solaris.iso"
  chcon unconfined_u:object_r:lib_t:s0 "/usr/lib/vmware/isoimages/solaris.iso"

  # Disable VMWare Automatic Startup
  systemctl daemon-reload
  systemctl disable vmware.service
  systemctl disable vmware-USBArbitrator.service
  # systemctl disable vmware-workstation-server.service
  
  # Add dependency info so the systemd generator knows how these services relate.
  # sed -i '/description.*/a \### BEGIN INIT INFO\n# Provides:       vmware-workstation-server\n### END INIT INFO\n' /etc/rc.d/init.d/vmware-workstation-server
  sed -i '/description.*/a \### BEGIN INIT INFO\n# Provides:       vmware\n# Required-Start: vmware-workstation-server\n# Required-Stop:\n### END INIT INFO\n' /etc/rc.d/init.d/vmware

  # Setup the Virtual Interfaces as Trusted
  if [ -f /usr/bin/firewall-cmd ]; then
    firewall-cmd --zone=trusted --add-interface=vmnet1
    firewall-cmd --zone=trusted --add-interface=vmnet8
    firewall-cmd --permanent --zone=trusted --add-interface=vmnet1
    firewall-cmd --permanent --zone=trusted --add-interface=vmnet8
  fi

  rm --force "$BASE/VMware-Tools-10.1.15-other-6677369.tar.gz"
  rm --force "$BASE/VMware-Workstation-Full-16.2.5-20904516.x86_64.bundle"

  # Install the dependencies.
  dnf --assumeyes install pcsc-lite-libs
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
  dnf --assumeyes --enablerepo=virtualbox install VirtualBox-6.1.x86_64

  # Virtual Box Extensions, if X windows is installed.
  if [ -f /usr/bin/X ]; then

    # Determine the download URL.
    VBOXVER=`VBoxManage --version | awk -F'r' '{print $1}'`
    VBOXEXT="Oracle_VM_VirtualBox_Extension_Pack-${VBOXVER}.vbox-extpack"
    VBOXEXTURL="https://download.virtualbox.org/virtualbox/${VBOXVER}/${VBOXEXT}"

    # Download the extension pack.
    curl "${VBOXEXTURL}" > "${VBOXEXT}"

    # Calculate the license hash.
    VBOXACCEPT=`tar --extract --to-stdout --file="${VBOXEXT}" ./ExtPack-license.txt | sha256sum | awk -F' ' '{print $1}'`

    # Uncomment this line to install the VirtualBox extensions.
    VBoxManage extpack install --replace --accept-license="${VBOXACCEPT}" "${VBOXEXT}"

    # Cleanup the downloaded file.
    rm --force "${VBOXEXT}"
  fi

  # Disable automatic startup.
  systemctl disable vboxautostart-service.service
  systemctl disable vboxballoonctrl-service.service
  systemctl disable vboxweb-service.service
  systemctl disable vboxdrv.service

  # Add the key users to the vboxusers group.
  usermod -aG vboxusers root
  usermod -aG vboxusers $HUMAN

  # Setup the Virtual Interfaces as Trusted
  if [ -f /usr/bin/firewall-cmd ]; then
    firewall-cmd --zone=trusted --add-interface=vibr0
    firewall-cmd --zone=trusted --add-interface=vibr1
    firewall-cmd --permanent --zone=trusted --add-interface=vibr0
    firewall-cmd --permanent --zone=trusted --add-interface=vibr1

  fi

  # Fix a permission issue to avoid spurious error messages in the system log.
  if [ -f /usr/lib/virtualbox/VMMR0.r0 ]; then
    chmod 755 /usr/lib/virtualbox/VMMR0.r0
  fi
  if [ -f /usr/lib/virtualbox/VBoxDDR0.r0 ]; then
    chmod 755 /usr/lib/virtualbox/VBoxDDR0.r0
  fi

  # If there is a set of user preferences, relocate the default box directory and disable update checks.
  VBoxManage setextradata global GUI/UpdateDate never
  if [ -f $HOME/.config/VirtualBox/VirtualBox.xml ]; then
     sed -i "s/defaultMachineFolder=\"[^\"]*\"/defaultMachineFolder=\"${HOME////\\/}\/\.virtualbox\"/g" $HOME/.config/VirtualBox/VirtualBox.xml
  fi

  sudo su -l $HUMAN <<-EOF 
  VBoxManage setextradata global GUI/UpdateDate never
if [ -f \$HOME/.config/VirtualBox/VirtualBox.xml ]; then
     sed -i "s/defaultMachineFolder=\"[^\"]*\"/defaultMachineFolder=\"\${HOME////\\\\/}\/\.virtualbox\"/g" \$HOME/.config/VirtualBox/VirtualBox.xml
fi
EOF

}

function provide-docker() {
 
  # Ensure the EPEL Repo is Available
  dnf --assumeyes --enablerepo=extras install epel-release

  # Docker Install
  dnf --assumeyes --enablerepo=extras --enablerepo=epel install \
    podman podman-plugins podman-docker podman-compose python3-podman \
    python3-docker python3-dockerpty

  # Setup the Docker Group
  getent group docker >/dev/null || groupadd docker
  usermod -aG docker root
  usermod -aG docker $HUMAN

  # Disable Docker Automatic Startup
  systemctl disable podman.service
  systemctl disable podman-restart.service
  systemctl disable podman-auto-update.timer
  systemctl disable podman-auto-update.service

  # Use the overlay2 driver, not a logical volume.
  # sed -i "s/^STORAGE_DRIVER=.*$/STORAGE_DRIVER=overlay2/g" /usr/share/container-storage-setup/container-storage-setup
  # sed -i 's/^driver = ".*"$/driver = "overlay2"/g' /etc/containers/storage.conf 

  # Setup the Virtual Interfaces as Trusted
  # if [ -f /usr/bin/firewall-cmd ]; then
  #   firewall-cmd --zone=trusted --add-interface=docker0
  #   firewall-cmd --permanent --zone=trusted --add-interface=docker0
  # fi
}

function provide-vagrant() {
  
  # Attempt to find out the latest Vagrant version automatically.
  export VAGRANT_VERSION=$(curl --silent https://releases.hashicorp.com/vagrant/ | grep -Eo 'href="/vagrant/[0-9\.\]*/"' | sort --version-sort --reverse | head -1 | sed 's/href\=\"\/vagrant\/\([0-9\.]*\)\/\"/\1/g')

  # Translate the version into a URL for an RPM package.
  export VAGRANT_PACKAGE=$(curl --silent  "https://releases.hashicorp.com/vagrant/${VAGRANT_VERSION}/"  | grep -Eo "href=\"https://releases.hashicorp.com/vagrant/${VAGRANT_VERSION}/.*\.x86_64.rpm\"" | sort --version-sort --reverse  | head -1 | sed 's/href\=//g' | tr -d '"')

  # Download Vagrant
  curl --location --output "$BASE/vagrant_${VAGRANT_VERSION}_x86_64.rpm" "${VAGRANT_PACKAGE}"

  # Install Vagrant
  dnf --assumeyes install "$BASE/vagrant_${VAGRANT_VERSION}_x86_64.rpm"

  # The libvirt Headers are Required for the Vagrant Plugin
  dnf --assumeyes install libvirt-devel

  # Vagrant libvirt Plugin
  CONFIGURE_ARGS="with-libvirt-include=/usr/include/libvirt with-libvirt-lib=/usr/lib64" vagrant plugin install vagrant-libvirt

  # Delete the Download
  rm --force "$BASE/vagrant_${VAGRANT_VERSION}_x86_64.rpm"

  # If VMWare is installed, we need the helper service.
  if [ -f /bin/vmware ]; then

    # Attempt to find out the latest Vagrant version automatically.
    export VAGRANT_VMWARE_VERSION=$(curl --silent https://releases.hashicorp.com/vagrant-vmware-utility/ | grep -Eo 'href="/vagrant-vmware-utility/.*"' | sort --version-sort --reverse | head -1 | sed 's/href\=\"\/vagrant-vmware-utility\/\([0-9\.]*\)\/\"/\1/g')

    # Translate the version into a URL for an RPM package.
    export VAGRANT_VMWARE_PACKAGE=$(curl --silent  "https://releases.hashicorp.com/vagrant-vmware-utility/${VAGRANT_VMWARE_VERSION}/"  | grep -Eo "href=\"https://releases.hashicorp.com/vagrant-vmware-utility/${VAGRANT_VMWARE_VERSION}/.*\_x86_64.rpm\"" | sort --version-sort --reverse  | head -1 | sed 's/href\=//g' | tr -d '"')

    # Download Vagrant
    curl --location --output "$BASE/vagrant_vmware_${VAGRANT_VMWARE_VERSION}_x86_64.rpm" "${VAGRANT_VMWARE_PACKAGE}"

    # Install Vagrant
    dnf --assumeyes install "$BASE/vagrant_vmware_${VAGRANT_VMWARE_VERSION}_x86_64.rpm"
    
    systemctl daemon-reload && systemctl start vmware.service && systemctl start vagrant-vmware-utility.service

    # Vagrant VMWare Plugin
    CONFIGURE_ARGS="with-libvirt-include=/usr/include/libvirt with-libvirt-lib=/usr/lib64" vagrant plugin install vagrant-vmware-desktop
    
    rm --force "$BASE/vagrant_vmware_${VAGRANT_VMWARE_VERSION}_x86_64.rpm"
  fi

}

function provide-packer() {

  # Attempt to find out the latest Packer version automatically.
  export PACKER_VERSION=$(curl --silent https://releases.hashicorp.com/packer/ | grep -Eo 'href="/packer/[0-9\.\]*/"' | sort --version-sort --reverse | head -1 | sed 's/href\=\"\/packer\/\([0-9\.]*\)\/\"/\1/g')

  # Download Packer
  curl --location --output "$BASE/packer_${PACKER_VERSION}_linux_amd64.zip" "https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_linux_amd64.zip"

  # Decompress
  unzip "$BASE/packer_${PACKER_VERSION}_linux_amd64.zip"

  # Install
  install "$BASE/packer" /usr/local/bin/
  chown root:root /usr/local/bin/packer
  chcon unconfined_u:object_r:bin_t:s0 /usr/local/bin/packer

  # Ensure bash/csh use the local bin version instead of the default.
  printf "alias packer='/usr/local/bin/packer'\n" > /etc/profile.d/packer.sh
  printf "alias packer /usr/local/bin/packer\n" > /etc/profile.d/packer.csh

  chcon system_u:object_r:bin_t:s0 /etc/profile.d/packer.csh
  chcon system_u:object_r:bin_t:s0 /etc/profile.d/packer.sh

  rm --force "$BASE/packer"
  rm --force "$BASE/packer_${PACKER_VERSION}_linux_amd64.zip"

  PACKER_PLUGIN_PATH=/usr/local/bin/ /usr/local/bin/packer plugins install github.com/hashicorp/qemu
  PACKER_PLUGIN_PATH=/usr/local/bin/ /usr/local/bin/packer plugins install github.com/hashicorp/hyperv
  PACKER_PLUGIN_PATH=/usr/local/bin/ /usr/local/bin/packer plugins install github.com/hashicorp/docker
  PACKER_PLUGIN_PATH=/usr/local/bin/ /usr/local/bin/packer plugins install github.com/hashicorp/vmware
  PACKER_PLUGIN_PATH=/usr/local/bin/ /usr/local/bin/packer plugins install github.com/hashicorp/vagrant
  PACKER_PLUGIN_PATH=/usr/local/bin/ /usr/local/bin/packer plugins install github.com/hashicorp/parallels
  PACKER_PLUGIN_PATH=/usr/local/bin/ /usr/local/bin/packer plugins install github.com/hashicorp/virtualbox

}

function provide-setup() {

  # Update the System
  dnf --assumeyes update

  # Install Basic Packages
  dnf --assumeyes install vim wget curl git lsof gawk nload bind-utils jq parallel kernel-headers kernel-devel

  # Install the Development Tools
  # Needed to Compile VMWare/Virtualbox Kernel Modules
  dnf --assumeyes groupinstall "Development Tools"

  # Create Human User If Necessary
  if [ ! -d /home/$HUMAN/ ]; then
    getent passwd $HUMAN >/dev/null || useradd $HUMAN
  fi
}

function all() {
  provide-setup
  provide-limits

  provide-vbox
  # provide-lxc
  provide-docker
  provide-vmware
  provide-libvirt

  provide-packer
  provide-vagrant
}

# Verify Root Permissions
if [[ `id --user` != 0 ]]; then
  tput setaf 1; printf "\nError. Not running with root permissions.\n\n"; tput sgr0
  exit 2
fi

if [ "${HUMAN}x" == "x" ] || [ "${HUMAN}" == "root" ]; then
  tput setaf 1; printf "\nError. Unable to setup the human user. Run this script using sudo or set the HUMAN variable manually.\n\n"; tput sgr0
  exit 2
fi

# Ensure a Credentials File is Available
if [ -f $BASE/../../.credentialsrc ]; then
  source $BASE/../../.credentialsrc
else
  tput setaf 1; printf "\nError. The credentials file is missing.\n\n"; tput sgr0
  exit 2
fi

# The setup functions.
if [[ $1 == "setup" ]]; then provide-setup
elif [[ $1 == "limits" ]]; then provide-limits

# The install functions.
elif [[ $1 == "lxc" ]]; then provide-lxc
elif [[ $1 == "docker" ]]; then provide-docker
elif [[ $1 == "vmware" ]]; then provide-vmware
elif [[ $1 == "packer" ]]; then provide-packer
elif [[ $1 == "libvirt" ]]; then provide-libvirt
elif [[ $1 == "vagrant" ]]; then provide-vagrant
elif [[ $1 == "virtualbox" ]]; then provide-vbox

# The full monty.
elif [[ $1 == "all" ]]; then all

# Catchall
else
  echo ""
  echo " Configuration"
  echo $"  `basename $0` {setup|limits} or"
  echo ""
  echo " Installers"
  echo $"  `basename $0` {lxc|vmware|docker|packer|vagrant|libvirt|virtualbox} or"
  echo ""
  echo " Global"
  echo $"  `basename $0` {all}"
  echo ""
  echo " Please select a target and run this command again."
  echo ""
  exit 2
fi
