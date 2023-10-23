#!/bin/bash

# To add a new box.
# Find:     ^(.*)(EXISTING)(.*)$
# Replace:  $1$2$3\n$1ADDITION$3

# To use the latest libvirt plugin code.
# ./check.sh cleanup && \
# ./check.sh plugin-libvirt && \
# source env.sh && \
# git clone https://github.com/vagrant-libvirt/vagrant-libvirt.git && \
# cd vagrant-libvirt && \
# git tag 0.100.1 && \
# /opt/vagrant/embedded/bin/gem build vagrant-libvirt.gemspec && \
# vagrant plugin install vagrant-libvirt-0.100.1.gem && \
# cd .. && \
# vagrant plugin list

# To troubleshoot plugin build problems, replace (note the -V is capitalized 
# for the gem command):
# /opt/vagrant/embedded/bin/gem build vagrant-libvirt.gemspec 
# with 
# /opt/vagrant/embedded/bin/gem build -V vagrant-libvirt.gemspec

# Handle self referencing, sourcing etc.
if [[ $0 != $BASH_SOURCE ]]; then
  export CMD=$BASH_SOURCE
else
  export CMD=$0
fi

# Ensure a consistent working directory so relative paths work.
pushd "`dirname \"$CMD\"`" > /dev/null
export BASE="`pwd -P`"
popd > /dev/null
cd "$BASE"
export NAME="`basename \"$CMD\"`"

# Localize the Vagrant Home Directory
export VAGRANT_HOME=$BASE/vagrant.d/

if [ -x $OS ]; then
  export OS=`uname`
fi

export VAGRANT_HOME="$BASE/vagrant.d/"

function warn() {
  if [ $? -ne 0 ]; then
    printf "\nThe $(tput setaf 3; tput bold)$1 $2 $3$(tput sgr0) test run encountered a problem. Continuing. { !! }\n" | tee --append $BASE/log.txt
    for i in 1 2 3; do printf "\a"; sleep 1; done
  fi
}

function error() {
  if [ $? -ne 0 ]; then
    printf "\nThe $(tput setaf 1; tput bold)$1 $2 $3$(tput sgr0) test run failed! Exiting. { !! }\n" &>> $1-$2-$3.txt
    printf "\nThe $(tput setaf 1; tput bold)$1 $2 $3$(tput sgr0) test run failed! Exiting. { !! }\n" | tee --append $BASE/log.txt

    # Ensure any box that is started gets shutdown to prevent hypervisor conflicts.
    vagrant halt --force &> /dev/null
    for i in 1 2 3; do printf "\a"; sleep 1; done
    cd $BASE # && rm --force --recursive $1-$2 ;
    rm --force --recursive /tmp/.vbox-${VBOX_IPC_SOCKETID}-ipc
    unset XDG_CONFIG_HOME ; unset VBOX_USER_HOME ; unset VBOX_IPC_SOCKETID
    exit 1
  fi
}

function outcome() {
  if [ $? -ne 0 ]; then
    tput setaf 1; tput bold; printf "The $1 $2 $3 test run failed!\n" | tee --append $BASE/log.txt; tput sgr0
  else
    tput setaf 2; tput bold; printf "The $1 $2 $3 test run passed!\n" | tee --append $BASE/log.txt; tput sgr0
  fi
}

function start() {
  # Disable IPv6 or the VMware builder won't be able to load the Kick Start configuration.
  sudo sysctl net.ipv6.conf.all.disable_ipv6=1

  # Start the required services.
  sudo systemctl restart vboxdrv.service
  sudo systemctl restart libvirtd.service
  sudo systemctl restart docker-latest.service
  sudo systemctl restart vmware.service
  sudo systemctl restart vmware-USBArbitrator.service
  sudo systemctl restart vmware-workstation-server.service

  # Confirm the VMware modules loaded.
  if [ -f /usr/bin/vmware-modconfig ]; then
    MODS=`sudo /etc/init.d/vmware status | grep --color=none --extended-regexp "Module vmmon loaded|Module vmnet loaded" | wc -l`
    if [ "$MODS" != "2" ]; then
      sudo vmware-modconfig --console --install-all
      if [ $? != 0 ]; then
        tput setaf 1; tput bold; printf "\n\nThe vmware kernel modules failed to load properly...\n\n"; tput sgr0
        for i in 1 2 3; do printf "\a"; sleep 1; done
        exit 1
      fi
    fi
  fi

  # Vagrant VMWare Utility service
  if [ -f /opt/vagrant-vmware-desktop/bin/vagrant-vmware-utility ]; then
    sudo /opt/vagrant-vmware-desktop/bin/vagrant-vmware-utility api -port=9922 -log=info \
      -pid=/var/run/vagrant-vmware-utility.pid \
      -log-path=/var/log/vagrant-vmware-utility.log &
  fi

  # Confirm the VirtualBox kernel modules loaded.
  if [ -f /usr/lib/virtualbox/vboxdrv.sh ]; then
    /usr/lib/virtualbox/vboxdrv.sh status | grep --silent "VirtualBox kernel modules \(.*\) are loaded."
    if [ $? != 0 ]; then
      sudo /usr/lib/virtualbox/vboxdrv.sh setup
      tput setaf 1; tput bold; printf "\n\nthe virtualbox kernel modules failed to load properly...\n\n"; tput sgr0
      for i in 1 2 3; do printf "\a"; sleep 1; done
      exit 1
    fi
  fi
}

function plugin-libvirt() {
  # Check whether the required plugin-libvirts are installed.
  vagrant plugin list | grep --silent --extended-regexp "^vagrant-libvirt \([0-9\.]*, global\)$"

  # The grep return code tells us whether it found a match in the header or not.
  if [ $? != 0 ]; then
    vagrant plugin install vagrant-libvirt
    if [ $? != 0 ]; then
      tput setaf 1; tput bold; printf "\nThe libvirt plugin failed to install. Aborting.\n"; tput sgr0
      exit 1
     fi
  fi
  return 0
}

function plugin-vmware() {

  # Check for the vagrant utility package.
  rpm --query vagrant-vmware-utility | grep --silent "^vagrant-vmware-utility"

  if [ $? != 0 ]; then
    tput setaf 1; tput bold; printf "\nThe vagrant vmware utility package is missing. Aborting.\n"; tput sgr0
    exit 1
  fi

  # Check that the vagrant utility service is running.
  systemctl status vagrant-vmware-utility.service > /dev/null

  if [ $? != 0 ]; then
    PID="`ps --no-headers --format pid -C vagrant-vmware-utility`"
    if [[ -z $PID ]]; then
      tput setaf 1; tput bold; printf "\nThe vagrant vmware utility isn't running. Aborting.\n"; tput sgr0
      exit 1
    fi
  fi

  # Check whether the required plugin-libvirts are installed.
  vagrant plugin list | grep --silent --extended-regexp "^vagrant-vmware-desktop \([0-9\.]*, global\)$"

  # The grep return code tells us whether it found a match in the header or not.
  if [ $? != 0 ]; then
    bash -c "VAGRANT_HOME=$VAGRANT_HOME vagrant plugin install vagrant-vmware-desktop &> /dev/null" &> /dev/null
    if [ $? != 0 ]; then
      tput setaf 1; tput bold; printf "\nThe vmware plugin failed to install. Aborting.\n"; tput sgr0
      exit 1
    fi
    vagrant plugin license vagrant-vmware-desktop license.lic &> /dev/null
    if [ $? != 0 ]; then
      tput setaf 1; tput bold; printf "\nThe vmware plugin license failed to install. Aborting.\n"; tput sgr0
      exit 1
    fi
  fi
  return 0
}

function testcase() {
  local RESULT=0
  "${@}" && { RESULT=0 && return 0; } || RESULT="${?}"
  printf "\nThe ${*} test case failed..." >> $BASE/log.txt
  echo -e "\\nThe $(tput setaf 1)${*}$(tput sgr0) test case failed..." >&2
  return ${RESULT}
}

function box() {

  # Ensure a consistent starting path.
  cd $BASE

  # Check for the relevant plugins.
  if [ "$3" == "libvirt" ]; then
    plugin-libvirt &> /dev/null
  elif [ "$3" == "vmware" ]; then
    plugin-vmware &> /dev/null
  fi

  # If the directory exists already, remove it now so we can start fresh.
  if [ -d "$1-$2-$3" ]; then
      rm --force --recursive "$1-$2-$3" ; error $1 $2 $3
  fi

  # Make the directory and copy in the template.
  mkdir "$1-$2-$3" ; error $1 $2 $3

  # For the roboxes we always use a blank template, with the proper VERSION if provided.
  if [ "$1" == "roboxes" ] && [ "$VERSION" != "" ]; then
    cd "$1-$2-$3" ; error $1 $2 $3
    vagrant init --force --minimal --box-version $VERSION $1/$2 &>> "$1-$2-$3.txt" ; error $1 $2 $3
  # For the roboxes that don't require a specific VERSION.
  elif [ "$1" == "roboxes" ]; then
    cd "$1-$2-$3" ; error $1 $2 $3
    vagrant init --force --minimal $1/$2 &>> "$1-$2-$3.txt" ; error $1 $2 $3
  # For a specific VERSION of any other box that isn't in the roboxes organization.
  elif [ "$VERSION" != "" ]; then
    cp "$2.tpl" "$1-$2-$3/Vagrantfile" ; error $1 $2 $3
    cd "$1-$2-$3" ; error $1 $2 $3
    sed -i "s/  config.vm.box_check_update = true/  config.vm.box_check_update = false\n  config.vm.box_version = \"$VERSION\"/g" Vagrantfile; error $1 $2 $3
  # For testing the current version of any box that isn't in the roboxes organization.
  else
    cp "$2.tpl" "$1-$2-$3/Vagrantfile" ; error $1 $2 $3
    cd $1-$2-$3 ; error $1 $2 $3
  fi

  # Download and/or update the vagrant box image.
  if [ "$3" == "vmware" ] && [ "$VERSION" != "" ]; then
    vagrant box add --clean --force --provider vmware_desktop --box-version $VERSION $1/$2 &>> "$1-$2-$3.txt" ; error $1 $2 $3
  elif [ "$3" == "vmware" ]; then
    vagrant box add --clean --force --provider vmware_desktop $1/$2 &>> "$1-$2-$3.txt" ; error $1 $2 $3
  elif [ "$VERSION" != "" ]; then
    vagrant box add --clean --force --provider $3 --box-version $VERSION $1/$2 &>> "$1-$2-$3.txt" ; error $1 $2 $3
  else
    vagrant box add --clean --force --provider $3 $1/$2 &>> "$1-$2-$3.txt" ; error $1 $2 $3
  fi

  # Vagrant commands.
  if [ "$3" == "vmware" ]; then
    vagrant up --provider vmware_desktop &>> "$1-$2-$3.txt" ; error $1 $2 $3
  elif [ "$3" == "virtualbox" ]; then
    export VBOX_IPC_SOCKETID=$RANDOM
    export VBOX_USER_HOME="$BASE/$1-$2-$3/.virtbox"
    export XDG_CONFIG_HOME="$BASE/$1-$2-$3/.virtbox"
    vboxmanage setproperty machinefolder "$BASE/$1-$2-$3" &>> "$1-$2-$3.txt" ; error $1 $2 $3
    vagrant up --provider $3 &>> "$1-$2-$3.txt" ; error $1 $2 $3
  else
    vagrant up --provider $3 &>> "$1-$2-$3.txt" ; error $1 $2 $3
  fi

  # Test file uploads.
  # (testcase vagrant upload Vagrantfile) &>> "$1-$2-$3.txt" ; error $1 $2 $3

  # Test directory uploads.
  # (testcase vagrant upload .vagrant) &>> "$1-$2-$3.txt" ; error $1 $2 $3

  # Validate the ability to create sub-shells.
  (testcase vagrant ssh -- exit 0) &>> "$1-$2-$3.txt" ; error $1 $2 $3

  # Confirm a bash shell.
  # (testcase vagrant ssh -- echo "\$SHELL" | grep -q bash) &>> "$1-$2-$3.txt" ; error $1 $2 $3

  # Ensure the uploaded file/directory arrived.
  # (testcase vagrant ssh --command "if [ ! -f Vagrantfile ] || [ ! -d .vagrant ]; then exit 1; fi") &>> "$1-$2-$3.txt" ; error $1 $2 $3
  # (testcase vagrant ssh -- "if [ ! -f Vagrantfile ]; then exit 1; fi") &>> "$1-$2-$3.txt" ; error $1 $2 $3

  # Validate the resolver works, and we have network access.
  # (testcase vagrant ssh -- "ping -c 4 lavabit.com") &>> "$1-$2-$3.txt" ; error $1 $2 $3

  # Confirm the ability to download files.
  # (testcase vagrant ssh -- "curl --silent --user-agent \"Mozilla/5.0 (X11; Linux x86_64; rv:60.0) Gecko/20100101 Firefox/60.0\" --output /dev/null --url https://lavabit.com") &>> "$1-$2-$3.txt" ; error $1 $2 $3

  # Test the ability to sudo..
  # (testcase vagrant ssh -- "sudo -- touch /test.dat && sudo touch /etc/test.dat && sudo -- bash -c 'echo TestOption no >> /etc/ssh/sshd_config'") &>> "$1-$2-$3.txt" ; error $1 $2 $3

  # Start building a list of commands we check for explicitly.
  # (testcase vagrant ssh -- "(which grep && which curl && which cat && which date && which ping && which awk && which sed && which ssh && which man && which ps && which vim) > /dev/null; exit \$?") &>> "$1-$2-$3.txt" ; error $1 $2 $3

  # vagrant halt --force; warn $1 $2 $3
  vagrant destroy --force &>> "$1-$2-$3.txt" ; warn $1 $2 $3

  if [ "$3" == "vmware" ]; then
    vagrant box remove --force --all --provider vmware_desktop $1/$2 &>> "$1-$2-$3.txt" ; warn $1 $2 $3
  else
    vagrant box remove --force --all --provider $3 $1/$2 &>> "$1-$2-$3.txt" ; warn $1 $2 $3
  fi

  # Remove the box using virsh.
  if [ "$3" == "libvirt" ]; then

    export PATTERN="$1-$2-$3\_default"
    export DOMAINS=( `virsh --connect=qemu:///system list --name --all | grep --extended-regexp $PATTERN` )
    for domain in "${DOMAINS[@]}"; do
      if [ "`virsh --connect=qemu:///system domstate $domain | head -1`" != "stopped" ]; then
        virsh --connect=qemu:///system --debug=3 destroy $domain &>> "$1-$2-$3.txt" ; warn $1 $2 $3
      fi
      virsh --connect=qemu:///system --debug=3 undefine $domain &>> "$1-$2-$3.txt" ; warn $1 $2 $3
    done

    # Delete the disk images.
    PATTERN="$1-$2-libvirt_default.img"
    IMAGES=( `virsh --connect=qemu:///system vol-list default | awk -F' ' '{print $2}' | grep --extended-regexp $PATTERN` )
    for image in "${IMAGES[@]}"; do
      virsh --connect=qemu:///system --debug=3 vol-delete --pool default $image &>> "$1-$2-$3.txt" ; warn $1 $2 $3
    done

    # Delete the drive snapshot
    export PATTERN="$1-VAGRANTSLASH-$2\_vagrant_box_image_[0-9]+\.[0-9]+\.[0-9]+\_box.img"
    export IMAGES=( `virsh --connect=qemu:///system vol-list default | awk -F' ' '{print $2}' | grep --extended-regexp $PATTERN` )
    for image in "${IMAGES[@]}"; do
      virsh --connect=qemu:///system --debug=3 vol-delete --pool default $image &>> "$1-$2-$3.txt" ; warn $1 $2 $3
    done
  fi

  # Cleanup the subdirectory.
  cd $BASE && rm --force --recursive "$1-$2-$3"  ; rm --force --recursive /tmp/.vbox-${VBOX_IPC_SOCKETID}-ipc
  unset XDG_CONFIG_HOME ; unset VBOX_USER_HOME ; unset VBOX_IPC_SOCKETID

  return 0
}

function generic-virtualbox() {

  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "alma8" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "alma9" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "alpine35" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "alpine36" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "alpine37" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "alpine38" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "alpine39" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "alpine310" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "alpine311" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "alpine312" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "alpine313" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "alpine314" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "alpine315" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "alpine316" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "alpine317" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "alpine318" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "arch" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "centos6" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "centos7" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "centos8" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "centos8s" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "centos9s" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "debian8" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "debian9" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "debian10" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "debian11" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "debian12" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "devuan1" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "devuan2" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "devuan3" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "devuan4" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "devuan5" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "dragonflybsd5" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "dragonflybsd6" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "dragonflybsd" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "fedora25" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "fedora26" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "fedora27" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "fedora28" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "fedora29" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "fedora30" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "fedora31" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "fedora32" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "fedora33" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "fedora34" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "fedora35" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "fedora36" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "fedora37" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "fedora38" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "freebsd11" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "freebsd12" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "freebsd13" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "freebsd14" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "gentoo" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "hardenedbsd11" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "hardenedbsd12" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "hardenedbsd13" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "hardenedbsd" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "netbsd8" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "netbsd9" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "openbsd6" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "openbsd7" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "opensuse15" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "opensuse42" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "oracle6" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "oracle7" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "oracle8" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "oracle9" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "rhel6" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "rhel7" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "rhel8" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "rhel9" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "rocky8" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "rocky9" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "ubuntu1604" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "ubuntu1610" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "ubuntu1704" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "ubuntu1710" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "ubuntu1804" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "ubuntu1810" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "ubuntu1904" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "ubuntu1910" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "ubuntu2004" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "ubuntu2010" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "ubuntu2104" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "ubuntu2110" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "ubuntu2204" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "ubuntu2210" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "ubuntu2304" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "ubuntu2310" ); P=( "${P[@]}" "virtualbox" );

  export -f box ; export -f warn ; export -f error ; export -f outcome ; export -f testcase ; export -f plugin-vmware ; export -f plugin-libvirt
  parallel --jobs 1 --delay 60 --will-cite --line-buffer --xapply 'box {1} {2} {3} ; outcome {1} {2} {3}' ":::" "${O[@]}" ":::" "${B[@]}" ":::" "${P[@]}"
  unset O; unset B; unset P; wait

  tput setaf 4; tput bold; printf "\nThe generic virtualbox run finished.\n"; tput sgr0
}

function generic-libvirt() {

  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "alma8" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "alma9" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "alpine35" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "alpine36" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "alpine37" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "alpine38" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "alpine39" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "alpine310" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "alpine311" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "alpine312" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "alpine313" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "alpine314" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "alpine315" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "alpine316" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "alpine317" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "alpine318" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "arch" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "centos6" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "centos7" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "centos8" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "centos8s" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "centos9s" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "debian8" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "debian9" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "debian10" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "debian11" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "debian12" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "devuan1" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "devuan2" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "devuan3" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "devuan4" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "devuan5" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "dragonflybsd5" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "dragonflybsd6" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "dragonflybsd" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "fedora25" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "fedora26" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "fedora27" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "fedora28" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "fedora29" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "fedora30" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "fedora31" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "fedora32" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "fedora33" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "fedora34" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "fedora35" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "fedora36" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "fedora37" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "fedora38" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "freebsd11" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "freebsd12" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "freebsd13" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "freebsd14" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "gentoo" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "hardenedbsd11" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "hardenedbsd12" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "hardenedbsd13" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "hardenedbsd" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "netbsd8" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "netbsd9" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "openbsd6" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "openbsd7" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "opensuse15" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "opensuse42" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "oracle6" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "oracle7" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "oracle8" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "oracle9" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "rhel6" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "rhel7" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "rhel8" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "rhel9" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "rocky8" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "rocky9" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "ubuntu1604" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "ubuntu1610" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "ubuntu1704" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "ubuntu1710" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "ubuntu1804" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "ubuntu1810" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "ubuntu1904" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "ubuntu1910" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "ubuntu2004" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "ubuntu2010" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "ubuntu2104" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "ubuntu2110" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "ubuntu2204" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "ubuntu2210" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "ubuntu2304" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "ubuntu2310" ); P=( "${P[@]}" "libvirt" );

  export -f box ; export -f warn ; export -f error ; export -f outcome ; export -f testcase ; export -f plugin-vmware ; export -f plugin-libvirt
  plugin-libvirt && parallel --jobs 1 --delay 60 --will-cite --line-buffer --keep-order --xapply 'box {1} {2} {3} ; outcome {1} {2} {3}' ":::" "${O[@]}" ":::" "${B[@]}" ":::" "${P[@]}"
  unset O; unset B; unset P; wait

  tput setaf 4; tput bold; printf "\nThe generic libvirt run finished.\n"; tput sgr0
}

function generic-vmware() {

  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "alma8" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "alma9" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "alpine35" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "alpine36" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "alpine37" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "alpine38" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "alpine39" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "alpine310" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "alpine311" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "alpine312" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "alpine313" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "alpine314" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "alpine315" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "alpine316" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "alpine317" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "alpine318" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "arch" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "centos6" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "centos7" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "centos8" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "centos8s" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "centos9s" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "debian8" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "debian9" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "debian10" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "debian11" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "debian12" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "devuan1" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "devuan2" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "devuan3" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "devuan4" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "devuan5" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "dragonflybsd5" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "dragonflybsd6" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "dragonflybsd" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "fedora25" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "fedora26" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "fedora27" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "fedora28" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "fedora29" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "fedora30" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "fedora31" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "fedora32" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "fedora33" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "fedora34" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "fedora35" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "fedora36" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "fedora37" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "fedora38" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "freebsd11" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "freebsd12" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "freebsd13" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "freebsd14" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "gentoo" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "hardenedbsd11" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "hardenedbsd12" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "hardenedbsd13" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "hardenedbsd" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "netbsd8" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "netbsd9" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "openbsd6" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "openbsd7" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "opensuse15" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "opensuse42" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "oracle6" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "oracle7" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "oracle8" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "oracle9" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "rhel6" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "rhel7" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "rhel8" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "rhel9" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "rocky8" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "rocky9" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "ubuntu1604" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "ubuntu1610" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "ubuntu1704" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "ubuntu1710" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "ubuntu1804" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "ubuntu1810" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "ubuntu1904" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "ubuntu1910" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "ubuntu2004" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "ubuntu2010" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "ubuntu2104" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "ubuntu2110" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "ubuntu2204" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "ubuntu2210" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "ubuntu2304" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "generic" ); B=( "${B[@]}" "ubuntu2310" ); P=( "${P[@]}" "vmware" );

  export -f box ; export -f warn ; export -f error ; export -f outcome ; export -f testcase ; export -f plugin-vmware ; export -f plugin-libvirt
  plugin-vmware && parallel --jobs 1 --delay 60 --will-cite --line-buffer --keep-order --xapply 'box {1} {2} {3} ; outcome {1} {2} {3}' ":::" "${O[@]}" ":::" "${B[@]}" ":::" "${P[@]}"
  unset O; unset B; unset P; wait

  tput setaf 4; tput bold; printf "\nThe generic vmware run finished.\n"; tput sgr0
}

function generic-hyperv() {

  if [[ $OS == "Windows_NT" ]]; then
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "alma8" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "alma9" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "alpine35" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "alpine36" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "alpine37" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "alpine38" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "alpine39" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "alpine310" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "alpine311" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "alpine312" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "alpine313" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "alpine314" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "alpine315" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "alpine316" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "alpine317" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "alpine318" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "arch" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "centos6" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "centos7" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "centos8" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "centos8s" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "centos9s" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "debian8" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "debian9" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "debian10" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "debian11" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "debian12" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "devuan1" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "devuan2" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "devuan3" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "devuan4" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "devuan5" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "dragonflybsd5" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "dragonflybsd6" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "dragonflybsd" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "fedora25" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "fedora26" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "fedora27" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "fedora28" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "fedora29" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "fedora30" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "fedora31" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "fedora32" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "fedora33" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "fedora34" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "fedora35" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "fedora36" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "fedora37" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "fedora38" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "freebsd11" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "freebsd12" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "freebsd13" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "freebsd14" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "gentoo" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "hardenedbsd11" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "hardenedbsd12" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "hardenedbsd13" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "hardenedbsd" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "netbsd8" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "netbsd9" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "openbsd6" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "openbsd7" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "opensuse15" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "opensuse42" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "oracle6" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "oracle7" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "oracle8" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "oracle9" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "rhel6" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "rhel7" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "rhel8" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "rhel9" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "rocky8" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "rocky9" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "ubuntu1604" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "ubuntu1610" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "ubuntu1704" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "ubuntu1710" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "ubuntu1804" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "ubuntu1810" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "ubuntu1904" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "ubuntu1910" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "ubuntu2004" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "ubuntu2010" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "ubuntu2104" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "ubuntu2110" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "ubuntu2204" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "ubuntu2210" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "ubuntu2304" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "ubuntu2310" ); P=( "${P[@]}" "hyperv" );

    export -f box ; export -f warn ; export -f error ; export -f outcome ; export -f testcase ; export -f plugin-vmware ; export -f plugin-libvirt
    parallel --jobs 1 --delay 60 --will-cite --line-buffer --xapply 'box {1} {2} {3} ; outcome {1} {2} {3}' ":::" "${O[@]}" ":::" "${B[@]}" ":::" "${P[@]}"
    unset O; unset B; unset P; wait

    tput setaf 4; tput bold; printf "\nThe generic hyperv run finished.\n"; tput sgr0
  else
    tput setaf 4; tput bold; printf "\nThe generic hyperv run was skipped.\n"; tput sgr0
  fi
}

function generic-parallels() {

  if [[ `uname` == "Darwin" ]]; then
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "alma8" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "alma9" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "alpine35" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "alpine36" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "alpine37" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "alpine38" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "alpine39" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "alpine310" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "alpine311" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "alpine312" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "alpine313" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "alpine314" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "alpine315" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "alpine316" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "alpine317" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "alpine318" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "arch" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "centos6" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "centos7" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "centos8" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "centos8s" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "centos9s" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "debian8" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "debian9" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "debian10" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "debian11" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "debian12" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "devuan1" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "devuan2" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "devuan3" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "devuan4" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "devuan5" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "dragonflybsd5" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "dragonflybsd6" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "dragonflybsd" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "fedora25" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "fedora26" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "fedora27" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "fedora28" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "fedora29" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "fedora30" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "fedora31" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "fedora32" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "fedora33" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "fedora34" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "fedora35" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "fedora36" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "fedora37" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "fedora38" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "freebsd11" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "freebsd12" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "freebsd13" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "freebsd14" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "gentoo" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "hardenedbsd11" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "hardenedbsd12" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "hardenedbsd13" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "hardenedbsd" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "netbsd8" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "netbsd9" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "openbsd6" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "openbsd7" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "opensuse15" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "opensuse42" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "oracle6" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "oracle7" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "oracle8" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "oracle9" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "rhel6" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "rhel7" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "rhel8" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "rhel9" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "rocky8" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "rocky9" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "ubuntu1604" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "ubuntu1610" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "ubuntu1704" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "ubuntu1710" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "ubuntu1804" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "ubuntu1810" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "ubuntu1904" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "ubuntu1910" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "ubuntu2004" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "ubuntu2010" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "ubuntu2104" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "ubuntu2110" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "ubuntu2204" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "ubuntu2210" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "ubuntu2304" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "generic" ); B=( "${B[@]}" "ubuntu2310" ); P=( "${P[@]}" "parallels" );

    export -f box ; export -f warn ; export -f error ; export -f outcome ; export -f testcase ; export -f plugin-vmware ; export -f plugin-libvirt
    parallel --jobs 1 --delay 60 --will-cite --line-buffer --xapply 'box {1} {2} {3} ; outcome {1} {2} {3}' ":::" "${O[@]}" ":::" "${B[@]}" ":::" "${P[@]}"
    unset O; unset B; unset P; wait

    tput setaf 4; tput bold; printf "\nThe generic parallels run finished.\n"; tput sgr0
  else
    tput setaf 4; tput bold; printf "\nThe generic parallels run was skipped.\n"; tput sgr0
  fi
}

function robox-virtualbox() {

  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "alma8" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "alma9" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "alpine35" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "alpine36" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "alpine37" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "alpine38" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "alpine39" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "alpine310" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "alpine311" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "alpine312" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "alpine313" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "alpine314" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "alpine315" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "alpine316" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "alpine317" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "alpine318" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "arch" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "centos6" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "centos7" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "centos8" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "centos8s" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "centos9s" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "debian8" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "debian9" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "debian10" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "debian11" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "debian12" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "devuan1" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "devuan2" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "devuan3" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "devuan4" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "devuan5" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "dragonflybsd5" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "dragonflybsd6" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "dragonflybsd" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "fedora25" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "fedora26" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "fedora27" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "fedora28" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "fedora29" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "fedora30" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "fedora31" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "fedora32" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "fedora33" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "fedora34" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "fedora35" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "fedora36" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "fedora37" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "fedora38" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "freebsd11" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "freebsd12" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "freebsd13" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "freebsd14" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "gentoo" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "hardenedbsd11" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "hardenedbsd12" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "hardenedbsd13" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "hardenedbsd" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "netbsd8" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "netbsd9" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "openbsd6" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "openbsd7" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "opensuse15" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "opensuse42" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "oracle6" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "oracle7" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "oracle8" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "oracle9" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "rhel6" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "rhel7" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "rhel8" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "rhel9" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "rocky8" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "rocky9" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "ubuntu1604" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "ubuntu1610" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "ubuntu1704" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "ubuntu1710" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "ubuntu1804" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "ubuntu1810" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "ubuntu1904" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "ubuntu1910" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "ubuntu2004" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "ubuntu2010" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "ubuntu2104" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "ubuntu2110" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "ubuntu2204" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "ubuntu2210" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "ubuntu2304" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "ubuntu2310" ); P=( "${P[@]}" "virtualbox" );

  export -f box ; export -f warn ; export -f error ; export -f outcome ; export -f testcase ; export -f plugin-vmware ; export -f plugin-libvirt
  parallel --jobs 1 --delay 60 --will-cite --line-buffer --xapply 'box {1} {2} {3} ; outcome {1} {2} {3}' ":::" "${O[@]}" ":::" "${B[@]}" ":::" "${P[@]}"
  unset O; unset B; unset P; wait

  tput setaf 4; tput bold; printf "\nThe roboxes virtualbox run finished.\n"; tput sgr0
}

function robox-libvirt() {

  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "alma8" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "alma9" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "alpine35" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "alpine36" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "alpine37" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "alpine38" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "alpine39" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "alpine310" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "alpine311" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "alpine312" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "alpine313" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "alpine314" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "alpine315" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "alpine316" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "alpine317" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "alpine318" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "arch" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "centos6" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "centos7" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "centos8" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "centos8s" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "centos9s" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "debian8" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "debian9" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "debian10" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "debian11" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "debian12" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "devuan1" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "devuan2" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "devuan3" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "devuan4" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "devuan5" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "dragonflybsd5" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "dragonflybsd6" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "dragonflybsd" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "fedora25" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "fedora26" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "fedora27" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "fedora28" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "fedora29" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "fedora30" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "fedora31" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "fedora32" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "fedora33" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "fedora34" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "fedora35" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "fedora36" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "fedora37" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "fedora38" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "freebsd11" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "freebsd12" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "freebsd13" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "freebsd14" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "gentoo" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "hardenedbsd11" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "hardenedbsd12" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "hardenedbsd13" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "hardenedbsd" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "netbsd8" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "netbsd9" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "openbsd6" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "openbsd7" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "opensuse15" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "opensuse42" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "oracle6" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "oracle7" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "oracle8" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "oracle9" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "rhel6" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "rhel7" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "rhel8" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "rhel9" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "rocky8" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "rocky9" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "ubuntu1604" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "ubuntu1610" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "ubuntu1704" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "ubuntu1710" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "ubuntu1804" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "ubuntu1810" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "ubuntu1904" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "ubuntu1910" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "ubuntu2004" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "ubuntu2010" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "ubuntu2104" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "ubuntu2110" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "ubuntu2204" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "ubuntu2210" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "ubuntu2304" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "ubuntu2310" ); P=( "${P[@]}" "libvirt" );

  export -f box ; export -f warn ; export -f error ; export -f outcome ; export -f testcase ; export -f plugin-vmware ; export -f plugin-libvirt
  plugin-libvirt && parallel --jobs 1 --delay 60 --will-cite --line-buffer --keep-order --xapply 'box {1} {2} {3} ; outcome {1} {2} {3}' ":::" "${O[@]}" ":::" "${B[@]}" ":::" "${P[@]}"
  unset O; unset B; unset P; wait

  tput setaf 4; tput bold; printf "\nThe roboxes libvirt run finished.\n"; tput sgr0
}

function robox-vmware() {

  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "alma8" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "alma9" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "alpine35" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "alpine36" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "alpine37" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "alpine38" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "alpine39" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "alpine310" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "alpine311" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "alpine312" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "alpine313" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "alpine314" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "alpine315" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "alpine316" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "alpine317" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "alpine318" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "arch" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "centos6" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "centos7" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "centos8" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "centos8s" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "centos9s" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "debian8" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "debian9" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "debian10" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "debian11" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "debian12" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "devuan1" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "devuan2" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "devuan3" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "devuan4" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "devuan5" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "dragonflybsd5" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "dragonflybsd6" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "dragonflybsd" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "fedora25" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "fedora26" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "fedora27" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "fedora28" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "fedora29" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "fedora30" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "fedora31" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "fedora32" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "fedora33" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "fedora34" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "fedora35" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "fedora36" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "fedora37" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "fedora38" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "freebsd11" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "freebsd12" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "freebsd13" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "freebsd14" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "gentoo" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "hardenedbsd11" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "hardenedbsd12" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "hardenedbsd13" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "hardenedbsd" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "netbsd8" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "netbsd9" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "openbsd6" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "openbsd7" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "opensuse15" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "opensuse42" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "oracle6" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "oracle7" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "oracle8" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "oracle9" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "rhel6" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "rhel7" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "rhel8" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "rhel9" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "rocky8" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "rocky9" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "ubuntu1604" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "ubuntu1610" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "ubuntu1704" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "ubuntu1710" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "ubuntu1804" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "ubuntu1810" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "ubuntu1904" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "ubuntu1910" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "ubuntu2004" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "ubuntu2010" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "ubuntu2104" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "ubuntu2110" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "ubuntu2204" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "ubuntu2210" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "ubuntu2304" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "ubuntu2310" ); P=( "${P[@]}" "vmware" );

  export -f box ; export -f warn ; export -f error ; export -f outcome ; export -f testcase ; export -f plugin-vmware ; export -f plugin-libvirt
  plugin-vmware && parallel --jobs 1 --delay 60 --will-cite --line-buffer --keep-order --xapply 'box {1} {2} {3} ; outcome {1} {2} {3}' ":::" "${O[@]}" ":::" "${B[@]}" ":::" "${P[@]}"
  unset O; unset B; unset P; wait

  tput setaf 4; tput bold; printf "\nThe roboxes vmware run finished.\n"; tput sgr0
}

function robox-hyperv() {

  if [[ $OS == "Windows_NT" ]]; then
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "alma8" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "alma9" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "alpine35" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "alpine36" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "alpine37" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "alpine38" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "alpine39" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "alpine310" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "alpine311" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "alpine312" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "alpine313" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "alpine314" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "alpine315" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "alpine316" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "alpine317" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "alpine318" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "arch" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "centos6" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "centos7" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "centos8" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "centos8s" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "centos9s" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "debian8" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "debian9" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "debian10" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "debian11" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "debian12" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "devuan1" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "devuan2" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "devuan3" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "devuan4" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "devuan5" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "dragonflybsd5" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "dragonflybsd6" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "dragonflybsd" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "fedora25" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "fedora26" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "fedora27" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "fedora28" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "fedora29" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "fedora30" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "fedora31" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "fedora32" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "fedora33" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "fedora34" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "fedora35" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "fedora36" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "fedora37" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "fedora38" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "freebsd11" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "freebsd12" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "freebsd13" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "freebsd14" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "gentoo" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "hardenedbsd11" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "hardenedbsd12" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "hardenedbsd13" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "hardenedbsd" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "netbsd8" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "netbsd9" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "openbsd6" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "openbsd7" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "opensuse15" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "opensuse42" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "oracle6" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "oracle7" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "oracle8" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "oracle9" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "rhel6" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "rhel7" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "rhel8" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "rhel9" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "rocky8" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "rocky9" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "ubuntu1604" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "ubuntu1610" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "ubuntu1704" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "ubuntu1710" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "ubuntu1804" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "ubuntu1810" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "ubuntu1904" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "ubuntu1910" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "ubuntu2004" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "ubuntu2010" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "ubuntu2104" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "ubuntu2110" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "ubuntu2204" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "ubuntu2210" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "ubuntu2304" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "ubuntu2310" ); P=( "${P[@]}" "hyperv" );

    export -f box ; export -f warn ; export -f error ; export -f outcome ; export -f testcase ; export -f plugin-vmware ; export -f plugin-libvirt
    parallel --jobs 1 --delay 60 --will-cite --line-buffer --xapply 'box {1} {2} {3} ; outcome {1} {2} {3}' ":::" "${O[@]}" ":::" "${B[@]}" ":::" "${P[@]}"
    unset O; unset B; unset P; wait

    tput setaf 4; tput bold; printf "\nThe roboxes hyperv run finished.\n"; tput sgr0
  else
    tput setaf 4; tput bold; printf "\nThe roboxes hyperv run was skipped.\n"; tput sgr0
  fi
}

function robox-parallels() {

  if [[ `uname` == "Darwin" ]]; then
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "alma8" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "alma9" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "alpine35" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "alpine36" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "alpine37" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "alpine38" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "alpine39" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "alpine310" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "alpine311" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "alpine312" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "alpine313" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "alpine314" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "alpine315" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "alpine316" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "alpine317" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "alpine318" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "arch" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "centos6" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "centos7" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "centos8" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "centos8s" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "centos9s" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "debian8" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "debian9" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "debian10" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "debian11" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "debian12" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "devuan1" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "devuan2" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "devuan3" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "devuan4" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "devuan5" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "dragonflybsd5" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "dragonflybsd6" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "dragonflybsd" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "fedora25" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "fedora26" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "fedora27" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "fedora28" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "fedora29" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "fedora30" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "fedora31" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "fedora32" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "fedora33" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "fedora34" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "fedora35" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "fedora36" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "fedora37" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "fedora38" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "freebsd11" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "freebsd12" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "freebsd13" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "freebsd14" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "gentoo" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "hardenedbsd11" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "hardenedbsd12" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "hardenedbsd13" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "hardenedbsd" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "netbsd8" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "netbsd9" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "openbsd6" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "openbsd7" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "opensuse15" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "opensuse42" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "oracle6" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "oracle7" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "oracle8" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "oracle9" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "rhel6" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "rhel7" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "rhel8" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "rhel9" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "rocky8" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "rocky9" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "ubuntu1604" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "ubuntu1610" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "ubuntu1704" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "ubuntu1710" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "ubuntu1804" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "ubuntu1810" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "ubuntu1904" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "ubuntu1910" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "ubuntu2004" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "ubuntu2010" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "ubuntu2104" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "ubuntu2110" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "ubuntu2204" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "ubuntu2210" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "ubuntu2304" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "roboxes" ); B=( "${B[@]}" "ubuntu2310" ); P=( "${P[@]}" "parallels" );

    export -f box ; export -f warn ; export -f error ; export -f outcome ; export -f testcase ; export -f plugin-vmware ; export -f plugin-libvirt
    parallel --jobs 1 --delay 60 --will-cite --line-buffer --xapply 'box {1} {2} {3} ; outcome {1} {2} {3}' ":::" "${O[@]}" ":::" "${B[@]}" ":::" "${P[@]}"
    unset O; unset B; unset P; wait

    tput setaf 4; tput bold; printf "\nThe roboxes parallels run finished.\n"; tput sgr0
  else
    tput setaf 4; tput bold; printf "\nThe roboxes parallels run was skipped.\n"; tput sgr0
  fi
}

function magma-virtualbox() {

  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-centos6" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-centos7" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-centos8" ); P=( "${P[@]}" "virtualbox" );
# O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-centos8s" ); P=( "${P[@]}" "virtualbox" );
# O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-centos9s" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-ubuntu" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-ubuntu1604" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-ubuntu1610" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-ubuntu1704" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-ubuntu1710" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-ubuntu1804" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-ubuntu1810" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-ubuntu1904" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-ubuntu1910" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-ubuntu2004" ); P=( "${P[@]}" "virtualbox" );
# O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-ubuntu2010" ); P=( "${P[@]}" "virtualbox" );
# O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-ubuntu2104" ); P=( "${P[@]}" "virtualbox" );
# O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-ubuntu2110" ); P=( "${P[@]}" "virtualbox" );
# O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-ubuntu2204" ); P=( "${P[@]}" "virtualbox" );
# O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-ubuntu2210" ); P=( "${P[@]}" "virtualbox" );
# O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-ubuntu2304" ); P=( "${P[@]}" "virtualbox" );
# O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-ubuntu2310" ); P=( "${P[@]}" "virtualbox" );
# O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-alpine" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-debian" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-debian8" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-debian9" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-debian10" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-debian11" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-debian12" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-developer" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-fedora" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-fedora27" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-fedora28" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-fedora29" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-fedora30" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-fedora31" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-fedora32" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-fedora33" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-fedora34" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-fedora35" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-fedora36" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-fedora37" ); P=( "${P[@]}" "virtualbox" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-fedora38" ); P=( "${P[@]}" "virtualbox" );
# O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-arch" ); P=( "${P[@]}" "virtualbox" );
# O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-gentoo" ); P=( "${P[@]}" "virtualbox" );
# O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-freebsd" ); P=( "${P[@]}" "virtualbox" );
# O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-openbsd" ); P=( "${P[@]}" "virtualbox" );

  export -f box ; export -f warn ; export -f error ; export -f outcome ; export -f testcase ; export -f plugin-vmware ; export -f plugin-libvirt
  parallel --jobs 1 --delay 60 --will-cite --line-buffer --xapply 'box {1} {2} {3} ; outcome {1} {2} {3}' ":::" "${O[@]}" ":::" "${B[@]}" ":::" "${P[@]}"
  unset O; unset B; unset P; wait

  tput setaf 4; tput bold; printf "\nThe magma virtualbox run finished.\n"; tput sgr0
}

function magma-libvirt() {

  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-centos6" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-centos7" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-centos8" ); P=( "${P[@]}" "libvirt" );
# O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-centos8s" ); P=( "${P[@]}" "libvirt" );
# O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-centos9s" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-ubuntu" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-ubuntu1604" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-ubuntu1610" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-ubuntu1704" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-ubuntu1710" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-ubuntu1804" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-ubuntu1810" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-ubuntu1904" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-ubuntu1910" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-ubuntu2004" ); P=( "${P[@]}" "libvirt" );
# O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-ubuntu2010" ); P=( "${P[@]}" "libvirt" );
# O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-ubuntu2104" ); P=( "${P[@]}" "libvirt" );
# O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-ubuntu2110" ); P=( "${P[@]}" "libvirt" );
# O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-ubuntu2204" ); P=( "${P[@]}" "libvirt" );
# O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-ubuntu2210" ); P=( "${P[@]}" "libvirt" );
# O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-ubuntu2304" ); P=( "${P[@]}" "libvirt" );
# O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-ubuntu2310" ); P=( "${P[@]}" "libvirt" );
# O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-alpine" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-debian" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-debian8" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-debian9" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-debian10" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-debian11" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-debian12" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-developer" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-fedora" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-fedora27" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-fedora28" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-fedora29" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-fedora30" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-fedora31" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-fedora32" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-fedora33" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-fedora34" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-fedora35" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-fedora36" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-fedora37" ); P=( "${P[@]}" "libvirt" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-fedora38" ); P=( "${P[@]}" "libvirt" );
# O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-arch" ); P=( "${P[@]}" "libvirt" );
# O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-gentoo" ); P=( "${P[@]}" "libvirt" );
# O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-freebsd" ); P=( "${P[@]}" "libvirt" );
# O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-openbsd" ); P=( "${P[@]}" "libvirt" );

  export -f box ; export -f warn ; export -f error ; export -f outcome ; export -f testcase ; export -f plugin-vmware ; export -f plugin-libvirt
  plugin-libvirt && parallel --jobs 1 --delay 60 --will-cite --line-buffer --keep-order --xapply 'box {1} {2} {3} ; outcome {1} {2} {3}' ":::" "${O[@]}" ":::" "${B[@]}" ":::" "${P[@]}"
  unset O; unset B; unset P; wait

  tput setaf 4; tput bold; printf "\nThe magma libvirt run finished.\n"; tput sgr0
}

function magma-vmware() {

  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-centos6" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-centos7" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-centos8" ); P=( "${P[@]}" "vmware" );
# O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-centos8s" ); P=( "${P[@]}" "vmware" );
# O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-centos9s" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-ubuntu" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-ubuntu1604" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-ubuntu1610" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-ubuntu1704" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-ubuntu1710" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-ubuntu1804" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-ubuntu1810" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-ubuntu1904" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-ubuntu1910" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-ubuntu2004" ); P=( "${P[@]}" "vmware" );
# O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-ubuntu2010" ); P=( "${P[@]}" "vmware" );
# O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-ubuntu2104" ); P=( "${P[@]}" "vmware" );
# O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-ubuntu2110" ); P=( "${P[@]}" "vmware" );
# O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-ubuntu2204" ); P=( "${P[@]}" "vmware" );
# O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-ubuntu2210" ); P=( "${P[@]}" "vmware" );
# O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-ubuntu2304" ); P=( "${P[@]}" "vmware" );
# O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-ubuntu2310" ); P=( "${P[@]}" "vmware" );
# O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-alpine" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-debian" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-debian8" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-debian9" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-debian10" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-debian11" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-debian12" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-developer" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-fedora" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-fedora27" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-fedora28" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-fedora29" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-fedora30" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-fedora31" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-fedora32" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-fedora33" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-fedora34" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-fedora35" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-fedora36" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-fedora37" ); P=( "${P[@]}" "vmware" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-fedora38" ); P=( "${P[@]}" "vmware" );
#   O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-arch" ); P=( "${P[@]}" "vmware" );
#   O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-gentoo" ); P=( "${P[@]}" "vmware" );
#   O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-freebsd" ); P=( "${P[@]}" "vmware" );
#   O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-openbsd" ); P=( "${P[@]}" "vmware" );

  export -f box ; export -f warn ; export -f error ; export -f outcome ; export -f testcase ; export -f plugin-vmware ; export -f plugin-libvirt
  plugin-vmware && parallel --jobs 1 --delay 60 --will-cite --line-buffer --keep-order --xapply 'box {1} {2} {3} ; outcome {1} {2} {3}' ":::" "${O[@]}" ":::" "${B[@]}" ":::" "${P[@]}"
  unset O; unset B; unset P; wait

  tput setaf 4; tput bold; printf "\nThe magma vmware run finished.\n"; tput sgr0
}

function magma-hyperv() {

  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma" ); P=( "${P[@]}" "hyperv" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-centos6" ); P=( "${P[@]}" "hyperv" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-centos7" ); P=( "${P[@]}" "hyperv" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-centos8" ); P=( "${P[@]}" "hyperv" );
# O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-centos8s" ); P=( "${P[@]}" "hyperv" );
# O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-centos9s" ); P=( "${P[@]}" "hyperv" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-ubuntu" ); P=( "${P[@]}" "hyperv" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-ubuntu1604" ); P=( "${P[@]}" "hyperv" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-ubuntu1610" ); P=( "${P[@]}" "hyperv" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-ubuntu1704" ); P=( "${P[@]}" "hyperv" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-ubuntu1710" ); P=( "${P[@]}" "hyperv" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-ubuntu1804" ); P=( "${P[@]}" "hyperv" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-ubuntu1810" ); P=( "${P[@]}" "hyperv" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-ubuntu1904" ); P=( "${P[@]}" "hyperv" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-ubuntu1910" ); P=( "${P[@]}" "hyperv" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-ubuntu2004" ); P=( "${P[@]}" "hyperv" );
# O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-ubuntu2010" ); P=( "${P[@]}" "hyperv" );
# O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-ubuntu2104" ); P=( "${P[@]}" "hyperv" );
# O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-ubuntu2110" ); P=( "${P[@]}" "hyperv" );
# O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-ubuntu2204" ); P=( "${P[@]}" "hyperv" );
# O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-ubuntu2210" ); P=( "${P[@]}" "hyperv" );
# O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-ubuntu2304" ); P=( "${P[@]}" "hyperv" );
# O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-ubuntu2310" ); P=( "${P[@]}" "hyperv" );
# O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-alpine" ); P=( "${P[@]}" "hyperv" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-debian" ); P=( "${P[@]}" "hyperv" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-debian8" ); P=( "${P[@]}" "hyperv" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-debian9" ); P=( "${P[@]}" "hyperv" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-debian10" ); P=( "${P[@]}" "hyperv" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-debian11" ); P=( "${P[@]}" "hyperv" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-debian12" ); P=( "${P[@]}" "hyperv" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-developer" ); P=( "${P[@]}" "hyperv" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-fedora" ); P=( "${P[@]}" "hyperv" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-fedora27" ); P=( "${P[@]}" "hyperv" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-fedora28" ); P=( "${P[@]}" "hyperv" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-fedora29" ); P=( "${P[@]}" "hyperv" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-fedora30" ); P=( "${P[@]}" "hyperv" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-fedora31" ); P=( "${P[@]}" "hyperv" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-fedora32" ); P=( "${P[@]}" "hyperv" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-fedora33" ); P=( "${P[@]}" "hyperv" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-fedora34" ); P=( "${P[@]}" "hyperv" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-fedora35" ); P=( "${P[@]}" "hyperv" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-fedora36" ); P=( "${P[@]}" "hyperv" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-fedora37" ); P=( "${P[@]}" "hyperv" );
  O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-fedora38" ); P=( "${P[@]}" "hyperv" );
# O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-arch" ); P=( "${P[@]}" "hyperv" );
# O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-gentoo" ); P=( "${P[@]}" "hyperv" );
# O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-freebsd" ); P=( "${P[@]}" "hyperv" );
# O=( "${O[@]}" "lavabit" ); B=( "${B[@]}" "magma-openbsd" ); P=( "${P[@]}" "hyperv" );

  export -f box ; export -f warn ; export -f error ; export -f outcome ; export -f testcase ; export -f plugin-vmware ; export -f plugin-libvirt
  parallel --jobs 1 --delay 60 --will-cite --line-buffer --xapply 'box {1} {2} {3} ; outcome {1} {2} {3}' ":::" "${O[@]}" ":::" "${B[@]}" ":::" "${P[@]}"
  unset O; unset B; unset P; wait

  tput setaf 4; tput bold; printf "\nThe magma hyperv run was skipped.\n"; tput sgr0
}

function magma() {
  if [[ $OS == "Windows_NT" ]]; then
    magma-hyperv
  else
    magma-virtualbox
    magma-libvirt
    magma-vmware
  fi
}

function generic() {
  if [[ $OS == "Windows_NT" ]]; then
    generic-hyperv
  elif [[ `uname` == "Darwin" ]]; then
    generic-parallels
  else
    generic-virtualbox
    generic-libvirt
    generic-vmware
  fi
}

function roboxes() {
  if [[ $OS == "Windows_NT" ]]; then
    robox-hyperv
  elif [[ `uname` == "Darwin" ]]; then
    robox-parallels
  else
    robox-virtualbox
    robox-libvirt
    robox-vmware
  fi
}

function lineage() {
  if [[ $OS == "Windows_NT" ]]; then
    O=( "${O[@]}" "lineage" ); B=( "${B[@]}" "lineage" ); P=( "${P[@]}" "hyperv" );
    O=( "${O[@]}" "lineageos" ); B=( "${B[@]}" "lineage" ); P=( "${P[@]}" "hyperv" );

    export -f box ; export -f warn ; export -f error ; export -f outcome ; export -f testcase ; export -f plugin-vmware ; export -f plugin-libvirt
    parallel --jobs 1 --delay 60 --will-cite --line-buffer --xapply 'box {1} {2} {3} ; outcome {1} {2} {3}' ":::" "${O[@]}" ":::" "${B[@]}" ":::" "${P[@]}"
    unset O; unset B; unset P; wait

  elif [[ `uname` == "Darwin" ]]; then
    O=( "${O[@]}" "lineage" ); B=( "${B[@]}" "lineage" ); P=( "${P[@]}" "parallels" );
    O=( "${O[@]}" "lineageos" ); B=( "${B[@]}" "lineage" ); P=( "${P[@]}" "parallels" );

    export -f box ; export -f warn ; export -f error ; export -f outcome ; export -f testcase ; export -f plugin-vmware ; export -f plugin-libvirt
    parallel --jobs 1 --delay 60 --will-cite --line-buffer --xapply 'box {1} {2} {3} ; outcome {1} {2} {3}' ":::" "${O[@]}" ":::" "${B[@]}" ":::" "${P[@]}"
    unset O; unset B; unset P; wait

  else
    O=( "${O[@]}" "lineage" ); B=( "${B[@]}" "lineage" ); P=( "${P[@]}" "libvirt" );
    O=( "${O[@]}" "lineageos" ); B=( "${B[@]}" "lineage" ); P=( "${P[@]}" "libvirt" );
    O=( "${O[@]}" "lineage" ); B=( "${B[@]}" "lineage" ); P=( "${P[@]}" "virtualbox" );
    O=( "${O[@]}" "lineageos" ); B=( "${B[@]}" "lineage" ); P=( "${P[@]}" "virtualbox" );
    O=( "${O[@]}" "lineage" ); B=( "${B[@]}" "lineage" ); P=( "${P[@]}" "vmware" );
    O=( "${O[@]}" "lineageos" ); B=( "${B[@]}" "lineage" ); P=( "${P[@]}" "vmware" );

    export -f box ; export -f warn ; export -f error ; export -f outcome ; export -f testcase ; export -f plugin-vmware ; export -f plugin-libvirt
    plugin-vmware && plugin-libvirt && parallel --jobs 1 --delay 60 --will-cite --line-buffer --keep-order --xapply 'box {1} {2} {3} ; outcome {1} {2} {3}' ":::" "${O[@]}" ":::" "${B[@]}" ":::" "${P[@]}"
    unset O; unset B; unset P; wait

  fi
}

function cleanup() {

  # Search for the Virtual Box machine using the vboxmanage command.
  if [ `command -v vboxmanage` ]; then
    export PATTERN="(generic|roboxes)-[a-z0-9]*-virtualbox_default_[0-9\_]*|magma-[a-z0-9]*-virtualbox_default_[0-9\_]*|lineage-[a-z0-9\-]*-virtualbox_default_[0-9\_]*"
    export BOXES=( `vboxmanage list -s vms | awk -F' ' '{print $1}' | awk -F'"' '{print $2}' | grep --extended-regexp $PATTERN` )
    for box in "${BOXES[@]}"; do
      STATE="`vboxmanage showvminfo \"$box\" --machinereadable | grep --extended-regexp \"^VMState=\\".*\\"$\" | awk -F'\"' '{print $2}'`"
      if [ "$STATE" != "poweroff" ] && [ "$STATE" != "aborted" ] ; then
        vboxmanage controlvm "$box" poweroff
      fi
      vboxmanage unregistervm "$box" --delete
    done
  fi

  # Remove any stale box images stored in the system image directory using virsh.
  if [ "$OS" != "Windows_NT" ] && [[ `uname` != "Darwin" ]]; then

    # We only need to run these commands if the default libvirt storage pool exists.
    if [ `command -v virsh` ] && [ `virsh --connect=qemu:///system pool-list --name --all  | awk -F' ' '{print $1}' | grep --extended-regexp default` ]; then

      # Undefine the box domain.
      PATTERN="(generic|roboxes)-[a-z0-9]*-libvirt_default|magma-[a-z0-9]*-libvirt_default|lineage-[a-z0-9\-]*-libvirt_default"
      DOMAINS=( `virsh --connect=qemu:///system list --name --all | grep --extended-regexp $PATTERN` )
      for domain in "${DOMAINS[@]}"; do
        # If the domain is running, destroy (aka halt/kill) it before calling undefine.
        if [ "`virsh --connect=qemu:///system domstate $domain | head -1`" != "stopped" ]; then
          virsh --connect=qemu:///system --debug=3 destroy $domain
        fi
        virsh --connect=qemu:///system --debug=3 undefine $domain
      done

      # Delete the disk images.
      PATTERN="(generic|roboxes|lavabit|magma|lineageos|lineage)-[a-z0-9]*-libvirt_default.img"
      IMAGES=( `virsh --connect=qemu:///system vol-list default | awk -F' ' '{print $2}' | grep --extended-regexp $PATTERN` )
      for image in "${IMAGES[@]}"; do
        virsh --connect=qemu:///system --debug=3 vol-delete --pool default $image
      done

      # Delete the drive snapshot.
      PATTERN="(generic|roboxes|lavabit|magma|lineageos|lineage)-VAGRANTSLASH-[a-z0-9\-]*_vagrant_box_image_[0-9]+\.[0-9]+\.[0-9]+_box\.img"
      IMAGES=( `virsh --connect=qemu:///system vol-list default | awk -F' ' '{print $2}' | grep --extended-regexp $PATTERN` )
      for image in "${IMAGES[@]}"; do
        virsh --connect=qemu:///system --debug=3 vol-delete --pool default $image
      done

    fi

  fi

  # Vagrant VMWare Utility service
  # if [ -f /opt/vagrant-vmware-desktop/bin/vagrant-vmware-utility ]; then
  #   PID="`ps --no-headers --format pid -C vagrant-vmware-utility`"
  #   if [[ ! -z $PID ]]; then
  #     sudo kill $PID
  #     if [ -f /var/run/vagrant-vmware-utility.pid ]; then
  #       sudo rm --force /opt/vagrant-vmware-desktop/bin/vagrant-vmware-utility
  #     fi
  #   fi
  # fi

  rm --recursive --force $BASE/{generic,roboxes}-alma8-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-alma9-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-alpine35-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-alpine36-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-alpine37-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-alpine38-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-alpine39-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-alpine310-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-alpine311-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-alpine312-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-alpine313-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-alpine314-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-alpine315-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-alpine316-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-alpine317-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-alpine318-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-arch-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-centos6-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-centos7-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-centos8-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-centos8s-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-centos9s-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-debian8-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-debian9-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-debian10-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-debian11-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-debian12-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-devuan1-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-devuan2-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-devuan3-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-devuan4-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-devuan5-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-dragonflybsd5-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-dragonflybsd6-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-dragonflybsd-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-fedora25-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-fedora26-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-fedora27-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-fedora28-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-fedora29-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-fedora30-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-fedora31-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-fedora32-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-fedora33-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-fedora34-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-fedora35-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-fedora36-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-fedora37-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-fedora38-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-freebsd11-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-freebsd12-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-freebsd13-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-freebsd14-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-gentoo-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-hardenedbsd11-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-hardenedbsd12-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-hardenedbsd13-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-hardenedbsd-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-netbsd8-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-netbsd9-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-openbsd6-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-openbsd7-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-opensuse15-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-opensuse42-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-oracle6-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-oracle7-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-oracle8-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-oracle9-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-rhel6-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-rhel7-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-rhel8-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-rhel9-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-rocky8-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-rocky9-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-ubuntu1604-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-ubuntu1610-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-ubuntu1704-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-ubuntu1710-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-ubuntu1804-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-ubuntu1810-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-ubuntu1904-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-ubuntu1910-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-ubuntu2004-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-ubuntu2010-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-ubuntu2104-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-ubuntu2110-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-ubuntu2204-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-ubuntu2210-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-ubuntu2304-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{generic,roboxes}-ubuntu2310-{hyperv,libvirt,parallels,virtualbox,vmware}

  rm --recursive --force $BASE/{lavabit-magma,magma}-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{lavabit-magma,magma}-alpine-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{lavabit-magma,magma}-arch-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{lavabit-magma,magma}-centos-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{lavabit-magma,magma}-centos6-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{lavabit-magma,magma}-centos7-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{lavabit-magma,magma}-centos8-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{lavabit-magma,magma}-centos8s-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{lavabit-magma,magma}-centos9s-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{lavabit-magma,magma}-debian-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{lavabit-magma,magma}-debian8-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{lavabit-magma,magma}-debian9-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{lavabit-magma,magma}-debian10-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{lavabit-magma,magma}-debian11-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{lavabit-magma,magma}-debian12-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{lavabit-magma,magma}-developer-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{lavabit-magma,magma}-fedora-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{lavabit-magma,magma}-fedora27-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{lavabit-magma,magma}-fedora28-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{lavabit-magma,magma}-fedora29-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{lavabit-magma,magma}-fedora30-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{lavabit-magma,magma}-fedora31-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{lavabit-magma,magma}-fedora32-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{lavabit-magma,magma}-fedora33-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{lavabit-magma,magma}-fedora34-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{lavabit-magma,magma}-fedora35-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{lavabit-magma,magma}-fedora36-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{lavabit-magma,magma}-fedora37-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{lavabit-magma,magma}-fedora38-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{lavabit-magma,magma}-freebsd-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{lavabit-magma,magma}-gentoo-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{lavabit-magma,magma}-openbsd-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{lavabit-magma,magma}-ubuntu-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{lavabit-magma,magma}-ubuntu1604-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{lavabit-magma,magma}-ubuntu1610-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{lavabit-magma,magma}-ubuntu1704-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{lavabit-magma,magma}-ubuntu1710-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{lavabit-magma,magma}-ubuntu1804-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{lavabit-magma,magma}-ubuntu1810-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{lavabit-magma,magma}-ubuntu1904-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{lavabit-magma,magma}-ubuntu1910-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{lavabit-magma,magma}-ubuntu2004-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{lavabit-magma,magma}-ubuntu2010-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{lavabit-magma,magma}-ubuntu2104-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{lavabit-magma,magma}-ubuntu2110-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{lavabit-magma,magma}-ubuntu2204-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{lavabit-magma,magma}-ubuntu2210-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{lavabit-magma,magma}-ubuntu2304-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{lavabit-magma,magma}-ubuntu2310-{hyperv,libvirt,parallels,virtualbox,vmware}
  
  rm --recursive --force $BASE/{lineage,lineageos}-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{lineage,lineageos}-lineage-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{lineage,lineageos}-nash-{hyperv,libvirt,parallels,virtualbox,vmware}
  rm --recursive --force $BASE/{lineage,lineageos}-lineage-nash-{hyperv,libvirt,parallels,virtualbox,vmware}

  rm --force $BASE/log.txt $BASE/log.vm.txt $BASE/log.vmware.txt $BASE/log.hyperv.txt $BASE/log.libvirt.txt $BASE/log.parallels.txt $BASE/log.virtualbox.txt
  rm --recursive --force $BASE/vagrant-libvirt/
  rm --recursive --force $VAGRANT_HOME

}

function purge() {

  # Purge a specific box from the system.
  if [ "$OS" != "Windows_NT" ] && [[ `uname` != "Darwin" ]]; then

    # Check for the relevant plugins.
    if [ "$3" == "libvirt" ]; then
      plugin-libvirt &> /dev/null
    elif [ "$3" == "vmware" ]; then
      plugin-vmware &> /dev/null
    fi

    # Destroy the virtual machine, if necessary, and remove the box directory.
    if [ -d $1-$2-$3 ]; then
      cd $1-$2-$3 || (printf "\nThe $(tput setaf 3; tput bold)$1 $2 $3$(tput sgr0) purge failed.\n" ; exit 1)

      STATUS="`vagrant status --machine-readable | grep --only-matching --extended-regexp 'default,state,.*$' | awk -F',' '{print $3}'`"
      if [ "$STATUS" != "" ] && [ "$STATUS" != "not_created" ]; then
        vagrant destroy --force || (printf "\nThe $(tput setaf 3; tput bold)$1 $2 $3$(tput sgr0) box destruction failed.\n")
      fi

      # Cleanup the subdirectory.
      cd $BASE && rm --force --recursive "$1-$2-$3"
    fi

    # Remove the box image from the vagrant directory.
    if [ "$3" == "vmware" ]; then
      export PROVIDER="vmware_desktop"
    else
      export PROVIDER="$3"
    fi

    # If the box image exists, then delete it.
    STATUS=`vagrant box list | grep --extended-regexp "^$1/$2 \($PROVIDER, [0-9\.]*\)$"`
    if [ "$STATUS" != "" ]; then
      vagrant box remove --force --all --provider $PROVIDER $1/$2 || (printf "\nThe $(tput setaf 3; tput bold)$1 $2 $3$(tput sgr0) box removal failed.\n")
    fi

    # Search for the Virtual Box machine using the vboxmanage command.
    if [ "$3" == "virtualbox" ]; then
      export PATTERN="$1-$2-virtualbox_default_[0-9\_]*"
      export BOXES=( `vboxmanage list -s vms | awk -F' ' '{print $1}' | awk -F'"' '{print $2}' | grep --extended-regexp $PATTERN` )
      for box in "${BOXES[@]}"; do
        STATE="`vboxmanage showvminfo \"$box\" --machinereadable | grep --extended-regexp \"^VMState=\\".*\\"$\" | awk -F'\"' '{print $2}'`"
        if [ "$STATE" != "poweroff" ] && [ "$STATE" != "aborted" ] ; then
          vboxmanage controlvm "$box" poweroff
        fi
        vboxmanage unregistervm "$box" --delete
      done
    fi

    # Remove the domain, and disk images from the libvirt subsystem using virsh.
    if [ "$3" == "libvirt" ]; then

      export PATTERN="$1-$2-$3\_default"
      export DOMAINS=( `virsh --connect=qemu:///system list --name --all | grep --extended-regexp $PATTERN` )
      for domain in "${DOMAINS[@]}"; do
        if [ "`virsh --connect=qemu:///system domstate $domain | head -1`" != "stopped" ]; then
          virsh --connect=qemu:///system --debug=3 destroy $domain &>> "$1-$2-$3.txt"
        fi
        virsh --connect=qemu:///system --debug=3 undefine $domain &>> "$1-$2-$3.txt"
      done

      # Delete the disk images.
      PATTERN="$1-$2-libvirt_default.img"
      IMAGES=( `virsh --connect=qemu:///system vol-list default | awk -F' ' '{print $2}' | grep --extended-regexp $PATTERN` )
      for image in "${IMAGES[@]}"; do
        virsh --connect=qemu:///system --debug=3 vol-delete --pool default $image
      done

      # Delete the drive snapshot
      export PATTERN="$1-VAGRANTSLASH-$2\_vagrant_box_image_[0-9]+\.[0-9]+\.[0-9]+_box\.img"
      export IMAGES=( `virsh --connect=qemu:///system vol-list default | awk -F' ' '{print $2}' | grep --extended-regexp $PATTERN` )
      for image in "${IMAGES[@]}"; do
        virsh --connect=qemu:///system --debug=3 vol-delete --pool default $image &>> "$1-$2-$3.txt"
      done
    fi

  fi
}

function all() {
  start
  magma
  roboxes
  generic
  lineage
}

# The generic functions.
if [[ $1 == "start" ]]; then start
elif [[ $1 == "cleanup" ]]; then cleanup

# Plugin handlers.
elif [[ $1 == "plugin" ]]; then plugin-libvirt ; plugin-vmware
elif [[ $1 == "plugin-vmware" ]]; then plugin-vmware
elif [[ $1 == "plugin-libvirt" ]]; then plugin-libvirt

# The group builders.
elif [[ $1 == "magma" ]]; then magma
elif [[ $1 == "robox" ]]; then roboxes
elif [[ $1 == "roboxes" ]]; then roboxes
elif [[ $1 == "generic" ]]; then generic
elif [[ $1 == "lineage" ]]; then lineage

# The box runners.
elif [[ $1 == "magma-vmware" ]]; then magma-vmware
elif [[ $1 == "magma-libvirt" ]]; then magma-libvirt
elif [[ $1 == "magma-hyperv" ]]; then magma-hyperv
elif [[ $1 == "magma-virtualbox" ]]; then magma-virtualbox

elif [[ $1 == "generic-vmware" ]]; then generic-vmware
elif [[ $1 == "generic-libvirt" ]]; then generic-libvirt
elif [[ $1 == "generic-hyperv" ]]; then generic-hyperv
elif [[ $1 == "generic-parallels" ]]; then generic-parallels
elif [[ $1 == "generic-virtualbox" ]]; then generic-virtualbox

elif [[ $1 == "robox-vmware" ]]; then robox-vmware
elif [[ $1 == "robox-libvirt" ]]; then robox-libvirt
elif [[ $1 == "robox-hyperv" ]]; then robox-hyperv
elif [[ $1 == "robox-parallels" ]]; then robox-parallels
elif [[ $1 == "robox-virtualbox" ]]; then robox-virtualbox

elif [[ $1 == "roboxes-vmware" ]]; then robox-vmware
elif [[ $1 == "roboxes-libvirt" ]]; then robox-libvirt
elif [[ $1 == "roboxes-hyperv" ]]; then robox-hyperv
elif [[ $1 == "roboxes-parallels" ]]; then robox-parallels
elif [[ $1 == "roboxes-virtualbox" ]]; then robox-virtualbox

# Check a specific box.
elif [[ $1 == "box" ]]; then box $2 $3 $4 ; outcome $2 $3 $4
elif [[ $1 == "purge" ]]; then purge $2 $3 $4

# The full monty.
elif [[ $1 == "all" ]]; then all

# Catchall
else
  echo ""
  echo " Manage the Environment"
  echo $"  `basename $0` {start|cleanup} or "
  echo ""
  echo " Organizational Groupings"
  echo $"  `basename $0` {magma|roboxes|generic|lineage}"
  echo ""
  echo " Provider Specific Groupings"
  echo $"  `basename $0` {magma-virtualbox|magma-libvirt|magma-vmware|magma-hyperv}"
  echo $"  `basename $0` {roboxes-virtualbox|roboxes-libvirt|roboxes-parallels|roboxes-vmware|roboes-hyperv}"
  echo $"  `basename $0` {generic-virtualbox|generic-libvirt|generic-parallels|generic-vmware|generic-hyperv}"
  echo ""
  echo " Check a Speific Box"
  echo $"  `basename $0` {box ORGANIZATION NAME PROVIDER}"
  echo ""
  echo " Purge a Specific Box"
  echo $"  `basename $0` {purge ORGANIZATION NAME PROVIDER}"
  echo ""
  echo " Global"
  echo $"  `basename $0` {all}"
  echo ""
  echo " Please select a target and run this command again."
  echo ""
  exit 2
fi
