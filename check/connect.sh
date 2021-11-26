#!/bin/bash

# Handle self referencing, sourcing etc.
if [[ $0 != $BASH_SOURCE ]]; then
  export CMD=$BASH_SOURCE
else
  export CMD=$0
fi

# Ensure a consistent working directory so relative paths work.
pushd "`dirname \"$CMD\"`" > /dev/null
BASE="`pwd -P`"
popd > /dev/null
cd "$BASE"
NAME="`basename \"$CMD\"`"

# Localize the Vagrant Home Directory
export VAGRANT_HOME=$BASE/vagrant.d/

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

if [ $# != 3 ]; then
  tput bold; printf "\nUsage:\n\t$0 ORG BOX PROVIDER\n\n"; tput sgr0
  exit 1
fi

# Check for the relevant plugins.
if [ "$3" == "libvirt" ]; then
  plugin-libvirt &> /dev/null
elif [ "$3" == "vmware" ]; then
  plugin-vmware &> /dev/null
fi

if [ ! -d "$1-$2-$3" ]; then
  mkdir "$1-$2-$3"
fi

# For the roboxes we always use a blank template, with the proper VERSION if provided.
if [ "$1" == "roboxes" ] && [ "$VERSION" != "" ]; then
  cd "$1-$2-$3"
  vagrant init --force --minimal --box-version $VERSION $1/$2
# For the roboxes that don't require a specific VERSION.
elif [ "$1" == "roboxes" ]; then
  cd "$1-$2-$3"
  vagrant init --force --minimal $1/$2
# For a specific VERSION of any other box that isn't in the roboxes organization.
elif [ "$VERSION" != "" ]; then
  cp "$2.tpl" "$1-$2-$3/Vagrantfile"
  cd "$1-$2-$3"
  sed -i "s/  config.vm.box_check_update = true/  config.vm.box_check_update = false\n  config.vm.box_version = \"$VERSION\"/g" Vagrantfile
# For testing the current version of any box that isn't in the roboxes organization.
else
  cp "$2.tpl" "$1-$2-$3/Vagrantfile"
  cd "$1-$2-$3"
fi

# Download and/or update the vagrant box image.
if [ "$3" == "vmware" ] && [ "$VERSION" != "" ]; then
  vagrant box add --clean --force --provider vmware_desktop --box-version $VERSION $1/$2
elif [ "$3" == "vmware" ]; then
  vagrant box add --clean --force --provider vmware_desktop $1/$2
elif [ "$VERSION" != "" ]; then
  vagrant box add --clean --force --provider $3 --box-version $VERSION $1/$2
else
  vagrant box add --clean --force --provider $3 $1/$2
fi

# Vagrant commands.
if [ "$3" == "vmware" ]; then
  vagrant up --provider vmware_desktop
elif [ "$3" == "virtualbox" ]; then
  vboxmanage setproperty machinefolder "$BASE/$1-$2-$3"
  vagrant up --provider $3
else
  vagrant up --provider $3
fi

vagrant ssh
