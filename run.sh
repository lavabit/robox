#!/bin/bash

# Name: run.sh
# Author: Ladar Levison
#
# Description: Used to build various virtual machines using packer.

# Status
# FreeBND on Hyper-V is using 11.1 beta2.
# Failed to reboot without cdrom:
#  fedora
#  freebsd
#  oracle7
#  gentoo
# Failed to setup Hyper-V daemons:
#  debian
# OpenBSD needs guest agent install scripts.

# Version Information
export VERSION="1.2.6"
export AGENT="Vagrant/1.9.7 (+https://www.vagrantup.com; ruby2.3.4):"

# Limit the number of cpus packer will use.
export GOMAXPROCS="2"

# Ensure a consistent working directory so relative paths work.
LINK=`readlink -f $0`
BASE=`dirname $LINK`
cd $BASE

# Credentials and tokens.
source .credentialsrc

# The list of packer config files.
FILES="magma-docker.json magma-hyperv.json magma-vmware.json magma-libvirt.json magma-virtualbox.json "\
"generic-hyperv.json generic-vmware.json generic-libvirt.json generic-virtualbox.json "\
"lineage-hyperv.json lineage-vmware.json lineage-libvirt.json lineage-virtualbox.json"

# Collect the list of ISO urls.
ISOURLS=(`grep -E "iso_url|guest_additions_url" $FILES | grep -v "res/media/rhel-server-7.3-x86_64-dvd.iso" | awk -F'"' '{print $4}'`)
ISOSUMS=(`grep -E "iso_checksum|guest_additions_sha256" $FILES | grep -v "iso_checksum_type" | grep -v "120acbca7b3d55465eb9f8ef53ad7365f2997d42d4f83d7cc285bf5c71e1131f" | awk -F'"' '{print $4}'`)

# Collect the list of box names.
MAGMA_BOXES=`grep -E '"name":' $FILES | awk -F'"' '{print $4}' | grep "magma-" | sort --field-separator=- -k 3i -k 2.1,2.0`
GENERIC_BOXES=`grep -E '"name":' $FILES | awk -F'"' '{print $4}' | grep "generic-" | sort --field-separator=- -k 3i -k 2.1,2.0`
LINEAGE_BOXES=`grep -E '"name":' $FILES | awk -F'"' '{print $4}' | grep "lineage-" | sort --field-separator=- -k 3i -k 2.1,2.0`
BOXES="$LINEAGE_BOXES $GENERIC_BOXES $MAGMA_BOXES"

# Collect the list of box tags.
MAGMA_TAGS=`grep -E '"box_tag":' $FILES | awk -F'"' '{print $4}' | grep "magma" | sort -u --field-separator=- -k 3i -k 2.1,2.0`
GENERIC_TAGS=`grep -E '"box_tag":' $FILES | awk -F'"' '{print $4}' | grep "generic" | sort -u --field-separator=- -k 2i -k 1.1,1.0`
LINEAGE_TAGS=`grep -E '"box_tag":' $FILES | awk -F'"' '{print $4}' | grep "lineage" | sort -u --field-separator=- -k 2i -k 1.1,1.0`
# MAGMA_TAGS=`grep -E '"artifact":' $FILES | awk -F'"' '{print $4}' | grep "magma" | sort -u --field-separator=- -k 3i -k 2.1,2.0`
# GENERIC_TAGS=`grep -E '"artifact":' $FILES | awk -F'"' '{print $4}' | grep "generic" | sort -u --field-separator=- -k 2i -k 1.1,1.0`
# LINEAGE_TAGS=`grep -E '"artifact":' $FILES | awk -F'"' '{print $4}' | grep "lineage" | sort -u --field-separator=- -k 2i -k 1.1,1.0`
TAGS="$LINEAGE_TAGS $GENERIC_TAGS $MAGMA_TAGS"


function start() {
  # Disable IPv6 or the VMware builder won't be able to load the Kick Start configuration.
  sudo sysctl net.ipv6.conf.all.disable_ipv6=1

  # Start the required services.
  # sudo systemctl restart vmtoolsd.service
  sudo systemctl restart vboxdrv.service
  sudo systemctl restart libvirtd.service
  sudo systemctl restart docker-latest.service
  sudo systemctl restart vmware.service vmware-USBArbitrator.service vmware-workstation-server.service

  # Confirm the VirtualBox kernel modules loaded.
  if [ -f /usr/lib/virtualbox/vboxdrv.sh ]; then
    /usr/lib/virtualbox/vboxdrv.sh status | grep --color=none "VirtualBox kernel modules \(.*\) are loaded."
    if [ $? != 0 ]; then
      sudo /usr/lib/virtualbox/vboxdrv.sh setup
      tput setaf 1; tput bold; printf "\n\nThe virtualbox kernel modules failed to load properly...\n\n"; tput sgr0
      for i in 1 2 3; do printf "\a"; sleep 1; done
      exit 1
    fi
  fi
}

# Print the current URL and SHA hash for install discs which are updated frequently.
function isos {
  tput setaf 2; printf "\nArch\n\n"; tput sgr0;
  URL="https://mirrors.kernel.org/archlinux/iso/latest/"
  ISO=`curl --silent "${URL}" | grep --invert-match sha256 | grep --extended-regexp --only-matching --max-count=1 "archlinux\-[0-9]{4}\.[0-9]{2}\.[0-9]{2}\-x86\_64\.iso" | uniq`
  URL="${URL}${ISO}"
  SHA=`curl --silent "${URL}" | sha256sum | awk -F' ' '{print $1}'`
  printf "${URL}\n${SHA}\n\n"

  tput setaf 2; printf "\nGentoo\n\n"; tput sgr0;
  URL="https://mirrors.kernel.org/gentoo/releases/amd64/autobuilds/current-install-amd64-minimal/"
  ISO=`curl --silent "${URL}" | grep --invert-match sha256 | grep --extended-regexp --only-matching --max-count=1 "install\-amd64\-minimal\-[0-9]{8}\.iso" | uniq`
  URL="${URL}${ISO}"
  SHA=`curl --silent "${URL}" | sha256sum | awk -F' ' '{print $1}'`
  printf "${URL}\n${SHA}\n\n"

  tput setaf 2; printf "\nOpenSUSE\n\n"; tput sgr0;
  URL="https://mirrors.kernel.org/opensuse/distribution/leap/42.3/iso/"
  ISO=`curl --silent "${URL}" | grep --invert-match sha256 | grep --extended-regexp --only-matching --max-count=1 "openSUSE\-Leap\-42\.3\-NET\-x86\_64\-Build[0-9]{4}\-Media.iso|openSUSE\-Leap\-42\.3\-NET\-x86\_64.iso" | uniq`
  URL="${URL}${ISO}"
  SHA=`curl --silent "${URL}" | sha256sum | awk -F' ' '{print $1}'`
  printf "${URL}\n${SHA}\n\n"
}

# Verify all of the ISO locations are still valid.
function verify_url {

  # Grab just the response header and look for the 200 response code to indicate the link is valid.
  curl --silent --head "$1" | head -1 | grep --silent --extended-regexp "HTTP/1\.1 200 OK|HTTP/2\.0 200 OK"

  # The grep return code tells us whether it found a match in the header or not.
  if [ $? != 0 ]; then
    printf "Link Failure:  $1\n\n"
    exit 1
  fi
}

# Verify all of the ISO locations are valid and then download the ISO and verify the hash.
function verify_sum {

  # Grab just the response header and look for the 200 response code to indicate the link is valid.
  curl --silent --head "$1" | head -1 | grep --silent --extended-regexp "HTTP/1\.1 200 OK|HTTP/2\.0 200 OK"

  # The grep return code tells us whether it found a match in the header or not.
  if [ $? != 0 ]; then
    printf "Link Failure:  $1\n\n"
    exit 1
  fi

  # Grab the ISO and pipe the data through sha256sum, then compare the checksum value.
  curl --silent "$1" | sha256sum | grep --silent "$2"

  # The grep return code tells us whether it found a match in the header or not.
  if [ $? != 0 ]; then
    SUM=`curl --silent "$1" | sha256sum | awk -F' ' '{print $1}'`
    printf "Hash Failure:  $1\n"
    printf "Found       -  $SUM\n"
    printf "Expected    -  $SUM\n\n"
    exit 1
  fi

  printf "Validated   :  $1\n"
  return 0
}

# Validate the templates before building.
function verify_json() {
  packer validate $1.json
  if [[ $? != 0 ]]; then
    tput setaf 1; tput bold; printf "\n\nthe $1 packer template failed to validate...\n\n"; tput sgr0
    for i in 1 2 3; do printf "\a"; sleep 1; done
    exit 1
  fi
}

# Make sure the logging directory is avcailable. If it isn't, then create it.
function verify_logdir {

  if [ ! -d logs ]; then
    mkdir -p logs
  elif [ ! -d logs ]; then
    mkdir logs
  fi
}

# Build the boxes and cleanup the packer cache after each run.
function build() {

  verify_logdir
  export INCREMENT=1
  export PACKER_LOG="1"

  while [ $INCREMENT != 0 ]; do
    export PACKER_LOG_PATH="$BASE/logs/$1-${INCREMENT}.txt"
    if [ ! -f $PACKER_LOG_PATH ]; then
      let INCREMENT=0
    else
      let INCREMENT=$INCREMENT+1
    fi
  done

  packer build -on-error=cleanup -parallel=false $1.json

  if [[ $? != 0 ]]; then
    tput setaf 1; tput bold; printf "\n\n$1 images failed to build properly...\n\n"; tput sgr0
    for i in 1 2 3; do printf "\a"; sleep 1; done
  fi
}

# Build an individual box.
function box() {

  verify_logdir
  export PACKER_LOG="1"
  export TIMESTAMP=`date +"%Y%m%d.%I%M"`

  if [[ $OS == "Windows_NT" ]]; then
      export PACKER_LOG_PATH="$BASE/output/logs/magma-hyerpv-${TIMESTAMP}.txt"
      packer build -on-error=cleanup -parallel=false -only=$1 magma-hyerpv.json

      export PACKER_LOG_PATH="$BASE/output/logs/generic-hyerpv-${TIMESTAMP}.txt"
      packer build -on-error=cleanup -parallel=false -only=$1 generic-hyerpv.json

      export PACKER_LOG_PATH="$BASE/output/logs/lineage-hyperv-${TIMESTAMP}.txt"
      packer build -on-error=cleanup -parallel=false -only=$1 lineage-hyperv.json
  else
      export PACKER_LOG_PATH="$BASE/output/logs/magma-docker-${TIMESTAMP}.txt"
      packer build -on-error=cleanup -parallel=false -only=$1 magma-docker.json

      export PACKER_LOG_PATH="$BASE/output/logs/magma-vmware-${TIMESTAMP}.txt"
      packer build -on-error=cleanup -parallel=false -only=$1 magma-vmware.json

      export PACKER_LOG_PATH="$BASE/output/logs/magma-libvirt-${TIMESTAMP}.txt"
      packer build -on-error=cleanup -parallel=false -only=$1 magma-libvirt.json

      export PACKER_LOG_PATH="$BASE/output/logs/magma-virtualbox-${TIMESTAMP}.txt"
      packer build -on-error=cleanup -parallel=false -only=$1 magma-virtualbox.json

      export PACKER_LOG_PATH="$BASE/output/logs/generic-vmware-${TIMESTAMP}.txt"
      packer build -on-error=cleanup -parallel=false -only=$1 generic-vmware.json

      export PACKER_LOG_PATH="$BASE/output/logs/generic-libvirt-${TIMESTAMP}.txt"
      packer build -on-error=cleanup -parallel=false -only=$1 generic-libvirt.json

      export PACKER_LOG_PATH="$BASE/output/logs/generic-virtualbox-${TIMESTAMP}.txt"
      packer build -on-error=cleanup -parallel=false -only=$1 generic-virtualbox.json

      export PACKER_LOG_PATH="$BASE/output/logs/lineage-vmware-${TIMESTAMP}.txt"
      packer build -on-error=cleanup -parallel=false -only=$1 lineage-vmware.json

      export PACKER_LOG_PATH="$BASE/output/logs/lineage-libvirt-${TIMESTAMP}.txt"
      packer build -on-error=cleanup -parallel=false -only=$1 lineage-libvirt.json

      export PACKER_LOG_PATH="$BASE/output/logs/lineage-virtualbox-${TIMESTAMP}.txt"
      packer build -on-error=cleanup -parallel=false -only=$1 lineage-virtualbox.json
  fi
}

function links() {

  for ((i = 0; i < ${#ISOURLS[@]}; ++i)); do
      verify_url "${ISOURLS[$i]}" "${ISOSUMS[$i]}"
  done

  # Let the user know all of the links passed.
  printf "\nAll ${#ISOURLS[@]} of the install media locations are still valid...\n\n"
}

function sums() {

  for ((i = 0; i < ${#ISOURLS[@]}; ++i)); do
      verify_sum "${ISOURLS[$i]}" "${ISOSUMS[$i]}"
  done

  # Let the user know all of the links passed.
  printf "\nAll ${#ISOURLS[@]} of the install media locations are still valid...\n\n"
}

function validate() {
  verify_json magma-docker
  verify_json magma-hyperv
  verify_json magma-vmware
  verify_json magma-libvirt
  verify_json magma-virtualbox
  verify_json generic-hyperv
  verify_json generic-vmware
  verify_json generic-libvirt
  verify_json generic-virtualbox
  verify_json lineage-hyperv
  verify_json lineage-vmware
  verify_json lineage-libvirt
  verify_json lineage-virtualbox
}

function missing() {

    MISSING=0
    LIST=($BOXES)

    for ((i = 0; i < ${#LIST[@]}; ++i)); do
        if [ ! -f $BASE/output/"${LIST[$i]}-${VERSION}.box" ] && [ ! -f $BASE/output/"${LIST[$i]}-${VERSION}.tar.gz" ]; then
          let MISSING+=1
          printf "Box  -  "; tput setaf 1; printf "${LIST[$i]}\n"; tput sgr0
        else
          printf "Box  +  "; tput setaf 2; printf "${LIST[$i]}\n"; tput sgr0
        fi
    done

    # Let the user know how many boxes were missing.
    if [ $MISSING -eq 0 ]; then
      printf "\nAll ${#LIST[@]} of the boxes are present and accounted for...\n\n"
    else
      printf "\nOf the ${#LIST[@]} boxes defined, $MISSING are missing...\n\n"
    fi
}

function available() {

    MISSING=0
    LIST=($TAGS)

    for ((i = 0; i < ${#LIST[@]}; ++i)); do
      ORGANIZATION=`echo ${LIST[$i]} | awk -F'/' '{print $1}'`
      BOX=`echo ${LIST[$i]} | awk -F'/' '{print $2}'`

      PROVIDER="hyperv"
      curl --head --silent --location --user-agent '${AGENT}' "https://app.vagrantup.com/${ORGANIZATION}/boxes/${BOX}/versions/${VERSION}/providers/${PROVIDER}.box?access_token=${VAGRANT_CLOUD_TOKEN}" | head -1 | grep --silent --extended-regexp "HTTP/1\.1 200 OK|HTTP/2\.0 200 OK|HTTP/1\.1 302 Found|HTTP/2.0 302 Found"

      if [ $? != 0 ]; then
        let MISSING+=1
        printf "Box  -  "; tput setaf 1; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
      else
        printf "Box  +  "; tput setaf 2; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
      fi

      PROVIDER="libvirt"
      curl --head --silent --location --user-agent '${AGENT}' "https://app.vagrantup.com/${ORGANIZATION}/boxes/${BOX}/versions/${VERSION}/providers/${PROVIDER}.box?access_token=${VAGRANT_CLOUD_TOKEN}" | head -1 | grep --silent --extended-regexp "HTTP/1\.1 200 OK|HTTP/2\.0 200 OK|HTTP/1\.1 302 Found|HTTP/2.0 302 Found"

      if [ $? != 0 ]; then
        let MISSING+=1
        printf "Box  -  "; tput setaf 1; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
      else
        printf "Box  +  "; tput setaf 2; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
      fi

      PROVIDER="virtualbox"
      curl --head --silent --location --user-agent '${AGENT}' "https://app.vagrantup.com/${ORGANIZATION}/boxes/${BOX}/versions/${VERSION}/providers/${PROVIDER}.box?access_token=${VAGRANT_CLOUD_TOKEN}" | head -1 | grep --silent --extended-regexp "HTTP/1\.1 200 OK|HTTP/2\.0 200 OK|HTTP/1\.1 302 Found|HTTP/2.0 302 Found"

      if [ $? != 0 ]; then
        let MISSING+=1
        printf "Box  -  "; tput setaf 1; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
      else
        printf "Box  +  "; tput setaf 2; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
      fi

      PROVIDER="vmware_desktop"
      curl --head --silent --location --user-agent '${AGENT}' "https://app.vagrantup.com/${ORGANIZATION}/boxes/${BOX}/versions/${VERSION}/providers/${PROVIDER}.box?access_token=${VAGRANT_CLOUD_TOKEN}" | head -1 | grep --silent --extended-regexp "HTTP/1\.1 200 OK|HTTP/2\.0 200 OK|HTTP/1\.1 302 Found|HTTP/2.0 302 Found"

      if [ $? != 0 ]; then
        let MISSING+=1
        printf "Box  -  "; tput setaf 1; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
      else
        printf "Box  +  "; tput setaf 2; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
      fi
    done

    # Get the totla number of boxes.
    let TOTAL=${#LIST[@]}*4
    let FOUND=${TOTAL}-${MISSING}

    # Let the user know how many boxes were missing.
    if [ $MISSING -eq 0 ]; then
      printf "\nAll ${TOTAL} of the boxes are available...\n\n"
    else
      printf "\nOf the ${TOTAL} boxes defined, and ${FOUND} are privately available, while ${MISSING} are unavailable...\n\n"
    fi
}

function public() {

    MISSING=0
    LIST=($TAGS)

    for ((i = 0; i < ${#LIST[@]}; ++i)); do
      ORGANIZATION=`echo ${LIST[$i]} | awk -F'/' '{print $1}'`
      BOX=`echo ${LIST[$i]} | awk -F'/' '{print $2}'`

      PROVIDER="hyperv"
      curl --head --silent --location --user-agent '${AGENT}' "https://app.vagrantup.com/${ORGANIZATION}/boxes/${BOX}/versions/${VERSION}/providers/${PROVIDER}.box" | head -1 | grep --silent --extended-regexp "HTTP/1\.1 200 OK|HTTP/2\.0 200 OK|HTTP/1\.1 302 Found|HTTP/2.0 302 Found"

      if [ $? != 0 ]; then
        let MISSING+=1
        printf "Box  -  "; tput setaf 1; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
      else
        printf "Box  +  "; tput setaf 2; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
      fi

      PROVIDER="libvirt"
      curl --head --silent --location --user-agent '${AGENT}' "https://app.vagrantup.com/${ORGANIZATION}/boxes/${BOX}/versions/${VERSION}/providers/${PROVIDER}.box" | head -1 | grep --silent --extended-regexp "HTTP/1\.1 200 OK|HTTP/2\.0 200 OK|HTTP/1\.1 302 Found|HTTP/2.0 302 Found"

      if [ $? != 0 ]; then
        let MISSING+=1
        printf "Box  -  "; tput setaf 1; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
      else
        printf "Box  +  "; tput setaf 2; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
      fi

      PROVIDER="virtualbox"
      curl --head --silent --location --user-agent '${AGENT}' "https://app.vagrantup.com/${ORGANIZATION}/boxes/${BOX}/versions/${VERSION}/providers/${PROVIDER}.box" | head -1 | grep --silent --extended-regexp "HTTP/1\.1 200 OK|HTTP/2\.0 200 OK|HTTP/1\.1 302 Found|HTTP/2.0 302 Found"

      if [ $? != 0 ]; then
        let MISSING+=1
        printf "Box  -  "; tput setaf 1; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
      else
        printf "Box  +  "; tput setaf 2; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
      fi

      PROVIDER="vmware_desktop"
      curl --head --silent --location --user-agent '${AGENT}' "https://app.vagrantup.com/${ORGANIZATION}/boxes/${BOX}/versions/${VERSION}/providers/${PROVIDER}.box" | head -1 | grep --silent --extended-regexp "HTTP/1\.1 200 OK|HTTP/2\.0 200 OK|HTTP/1\.1 302 Found|HTTP/2.0 302 Found"

      if [ $? != 0 ]; then
        let MISSING+=1
        printf "Box  -  "; tput setaf 1; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
      else
        printf "Box  +  "; tput setaf 2; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
      fi
    done

    # Get the totla number of boxes.
    let TOTAL=${#LIST[@]}*4
    let FOUND=${TOTAL}-${MISSING}

    # Let the user know how many boxes were missing.
    if [ $MISSING -eq 0 ]; then
      printf "\nAll ${TOTAL} of the boxes are available...\n\n"
    else
      printf "\nOf the ${TOTAL} boxes defined, and ${FOUND} are publicly available, while ${MISSING} are unavailable...\n\n"
    fi
}

function cleanup() {
  rm -rf $BASE/packer_cache/ $BASE/output/ $BASE/logs/
}

function login() {
  docker login -u "$DOCKER_USER" -p "$DOCKER_PASSWORD"
  if [[ $? != 0 ]]; then
    tput setaf 1; tput bold; printf "\n\nThe docker login credentials failed.\n\n"; tput sgr0
    exit 1
  fi
}

function magma() {
  if [[ $OS == "Windows_NT" ]]; then
    build magma-hyperv
  else
    login ; build magma-docker
    build magma-vmware
    build magma-libvirt
    build magma-virtualbox
  fi
}

function generic() {
  if [[ $OS == "Windows_NT" ]]; then
    build generic-hyperv
  else
    build generic-vmware
    build generic-libvirt
    build generic-virtualbox
  fi
}

function lineage() {
  if [[ $OS == "Windows_NT" ]]; then
    build lineage-hyperv
  else
    build lineage-vmware
    build lineage-libvirt
    build lineage-virtualbox
  fi
}

function builder() {
  magma
  generic
  lineage
}

function all() {
  links
  validate

  start
  builder

  for i in 1 2 3 4 5 6 7 8 9 10; do printf "\a"; sleep 1; done
}

# The stage functions.
if [[ $1 == "start" ]]; then start
elif [[ $1 == "links" ]]; then links
elif [[ $1 == "validate" ]]; then validate
elif [[ $1 == "build" ]]; then builder
elif [[ $1 == "cleanup" ]]; then cleanup

# The helper functions.
elif [[ $1 == "isos" ]]; then isos
elif [[ $1 == "sums" ]]; then sums
elif [[ $1 == "missing" ]]; then missing
elif [[ $1 == "public" ]]; then public
elif [[ $1 == "available" ]]; then available

# The group builders.
elif [[ $1 == "magma" ]]; then magma
elif [[ $1 == "generic" ]]; then generic
elif [[ $1 == "lineage" ]]; then lineage

# The file builders.
elif [[ $1 == "magma-vmware" || $1 == "magma-vmware.json" ]]; then build magma-vmware
elif [[ $1 == "magma-hyperv" || $1 == "magma-hyperv.json" ]]; then build magma-hyperv
elif [[ $1 == "magma-libvirt" || $1 == "magma-libvirt.json" ]]; then build magma-libvirt
elif [[ $1 == "magma-docker" || $1 == "magma-docker.json" ]]; then login ; build magma-docker
elif [[ $1 == "magma-virtualbox" || $1 == "magma-virtualbox.json" ]]; then build magma-virtualbox

elif [[ $1 == "generic-vmware" || $1 == "generic-vmware.json" ]]; then build generic-vmware
elif [[ $1 == "generic-hyperv" || $1 == "generic-hyperv.json" ]]; then build generic-hyperv
elif [[ $1 == "generic-libvirt" || $1 == "generic-libvirt.json" ]]; then build generic-libvirt
elif [[ $1 == "generic-virtualbox" || $1 == "generic-virtualbox.json" ]]; then build generic-virtualbox

elif [[ $1 == "lineage-vmware" || $1 == "lineage-vmware.json" ]]; then build lineage-vmware
elif [[ $1 == "lineage-hyperv" || $1 == "lineage-hyperv.json" ]]; then build lineage-hyperv
elif [[ $1 == "lineage-libvirt" || $1 == "lineage-libvirt.json" ]]; then build lineage-libvirt
elif [[ $1 == "lineage-virtualbox" || $1 == "lineage-virtualbox.json" ]]; then build lineage-virtualbox

# Build a specific box.
elif [[ $1 == "box" ]]; then box $2

# The full monty.
elif [[ $1 == "all" ]]; then all

# Catchall
else
  echo ""
  echo " Stages"
  echo $"  `basename $0` {start|links|validate|build|cleanup} or "
  echo ""
  echo " Helpers"
  echo $"  `basename $0` {isos|sunms|missing|public|available} or "
  echo ""
  echo " Groups"
  echo $"  `basename $0` {magma|generic|lineage}"
  echo ""
  echo " Boxes"
  echo $"  `basename $0` {box NAME}"
  echo ""
  echo " Global"
  echo $"  `basename $0` {all}"
  echo ""
  echo " Please select a target and run this command again."
  echo ""
  exit 2
fi
