#!/bin/bash

# Name: run.sh
# Author: Ladar Levison
#
# Description: Used to build various virtual machines using packer.

# Limit the number of cpus packer will use.
export GOMAXPROCS="2"

# Ensure a consistent working directory so relative paths work.
LINK=`readlink -f $0`
BASE=`dirname $LINK`
cd $BASE

# Credentials and tokens.
export VERSION="0.9.14"
source .credentialsrc

# The list of packer config files.
FILES="magma-docker.json magma-hyperv.json magma-vmware.json magma-libvirt.json magma-virtualbox.json generic-hyperv.json generic-vmware.json generic-libvirt.json generic-virtualbox.json"

# Collect the list of ISO urls.
ISOURLS=(`grep -E "iso_url|guest_additions_url" $FILES | awk -F'"' '{print $4}'`)
ISOSUMS=(`grep -E "iso_checksum|guest_additions_sha256" $FILES | grep -v "iso_checksum_type" | awk -F'"' '{print $4}'`)

# Collect the list of box names.
MAGMA_BOXES=`grep -E '"name":' $FILES | awk -F'"' '{print $4}' | grep "magma-" | sort --field-separator=- -k 3i -k 2.1,2.0`
GENERIC_BOXES=`grep -E '"name":' $FILES | awk -F'"' '{print $4}' | grep "generic-" | sort --field-separator=- -k 3i -k 2.1,2.0`
LINEAGE_BOXES=`grep -E '"name":' $FILES | awk -F'"' '{print $4}' | grep "lineage-" | sort --field-separator=- -k 3i -k 2.1,2.0`
BOXES="$LINEAGE_BOXES $GENERIC_BOXES $MAGMA_BOXES"

# Collect the list of box tags.
# MAGMA_TAGS=`grep -E '"box_tag":' $FILES | awk -F'"' '{print $4}' | grep "magma" | sort -u --field-separator=- -k 3i -k 2.1,2.0`
# GENERIC_TAGS=`grep -E '"box_tag":' $FILES | awk -F'"' '{print $4}' | grep "generic" | sort -u --field-separator=- -k 2i -k 1.1,1.0`
# LINEAGE_TAGS=`grep -E '"box_tag":' $FILES | awk -F'"' '{print $4}' | grep "lineage" | sort -u --field-separator=- -k 2i -k 1.1,1.0`
MAGMA_TAGS=`grep -E '"artifact":' $FILES | awk -F'"' '{print $4}' | grep "magma" | sort -u --field-separator=- -k 3i -k 2.1,2.0`
GENERIC_TAGS=`grep -E '"artifact":' $FILES | awk -F'"' '{print $4}' | grep "generic" | sort -u --field-separator=- -k 2i -k 1.1,1.0`
LINEAGE_TAGS=`grep -E '"artifact":' $FILES | awk -F'"' '{print $4}' | grep "lineage" | sort -u --field-separator=- -k 2i -k 1.1,1.0`
TAGS="$LINEAGE_TAGS $GENERIC_TAGS $MAGMA_TAGS"

function start() {
  # Disable IPv6 or the VMware builder won't be able to load the Kick Start configuration.
  sudo sysctl net.ipv6.conf.all.disable_ipv6=1

  # Start the required services.
  sudo systemctl restart vmtoolsd.service
  sudo systemctl restart vboxdrv.service
  sudo systemctl restart libvirtd.service
  sudo systemctl restart docker-latest.service
  sudo systemctl restart vmware.service vmware-USBArbitrator.service vmware-workstation-server.service
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

  if [ ! -d output ]; then
    mkdir -p output/logs
  elif [ ! -d output/logs ]; then
    mkdir output/logs
  fi
}

# Build the boxes and cleanup the packer cache after each run.
function build() {

  verify_logdir
  export PACKER_LOG="1"
  export TIMESTAMP=`date +"%s"`
  export PACKER_LOG_PATH="$BASE/output/logs/$1-${TIMESTAMP}.txt"

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
  export TIMESTAMP=`date +"%s"`

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

  if [[ $? != 0 ]]; then
    tput setaf 1; tput bold; printf "\n\n$1 images failed to build properly...\n\n"; tput sgr0
    for i in 1 2 3; do printf "\a"; sleep 1; done
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
      curl --silent --head "https://vagrantcloud.com/api/v1/box/${ORGANIZATION}/${BOX}/version/${VERSION}/provider/${PROVIDER}?access_token=${ATLAS_TOKEN}" | head -1 | grep --silent --extended-regexp "HTTP/1\.1 200 OK|HTTP/2\.0 200 OK"

      if [ $? != 0 ]; then
        let MISSING+=1
        printf "Box  -  "; tput setaf 1; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
      else
        printf "Box  +  "; tput setaf 2; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
      fi

      PROVIDER="libvirt"
      curl --silent --head "https://vagrantcloud.com/api/v1/box/${ORGANIZATION}/${BOX}/version/${VERSION}/provider/${PROVIDER}?access_token=${ATLAS_TOKEN}" | head -1 | grep --silent --extended-regexp "HTTP/1\.1 200 OK|HTTP/2\.0 200 OK"

      if [ $? != 0 ]; then
        let MISSING+=1
        printf "Box  -  "; tput setaf 1; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
      else
        printf "Box  +  "; tput setaf 2; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
      fi

      PROVIDER="virtualbox"
      curl --silent --head "https://vagrantcloud.com/api/v1/box/${ORGANIZATION}/${BOX}/version/${VERSION}/provider/${PROVIDER}?access_token=${ATLAS_TOKEN}" | head -1 | grep --silent --extended-regexp "HTTP/1\.1 200 OK|HTTP/2\.0 200 OK"

      if [ $? != 0 ]; then
        let MISSING+=1
        printf "Box  -  "; tput setaf 1; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
      else
        printf "Box  +  "; tput setaf 2; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
      fi

      PROVIDER="vmware_desktop"
      curl --silent --head "https://vagrantcloud.com/api/v1/box/${ORGANIZATION}/${BOX}/version/${VERSION}/provider/${PROVIDER}?access_token=${ATLAS_TOKEN}" | head -1 | grep --silent --extended-regexp "HTTP/1\.1 200 OK|HTTP/2\.0 200 OK"

      if [ $? != 0 ]; then
        let MISSING+=1
        printf "Box  -  "; tput setaf 1; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
      else
        printf "Box  +  "; tput setaf 2; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
      fi
    done

    # Get the totla number of boxes.
    let TOTAL=${#LIST[@]}*4

    # Let the user know how many boxes were missing.
    if [ $MISSING -eq 0 ]; then
      printf "\nAll ${TOTAL} of the boxes are available...\n\n"
    else
      printf "\nOf the ${TOTAL} boxes defined, $MISSING are unavailable from the vagrant cloud...\n\n"
    fi
}

function cleanup() {
  rm -rf packer_cache/ output/
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

function all() {
  links
  validate

  start
  magma
  generic

  for i in 1 2 3 4 5 6 7 8 9 10; do printf "\a"; sleep 1; done
}


# The generic functions.
if [[ $1 == "start" ]]; then start
elif [[ $1 == "links" ]]; then links
elif [[ $1 == "sums" ]]; then sums
elif [[ $1 == "validate" ]]; then validate
elif [[ $1 == "missing" ]]; then missing
elif [[ $1 == "available" ]]; then available
elif [[ $1 == "cleanup" ]]; then cleanup

# The group builders.
elif [[ $1 == "magma" ]]; then magma
elif [[ $1 == "generic" ]]; then generic

# The file builders.
elif [[ $1 == "magma-docker" || $1 == "magma-docker.json" ]]; then login ; build magma-docker
elif [[ $1 == "magma-vmware" || $1 == "magma-vmware.json" ]]; then build magma-vmware
elif [[ $1 == "magma-libvirt" || $1 == "magma-libvirt.json" ]]; then build magma-libvirt
elif [[ $1 == "magma-hyperv" || $1 == "magma-hyperv.json" ]]; then build magma-hyperv
elif [[ $1 == "magma-virtualbox" || $1 == "magma-virtualbox.json" ]]; then build magma-virtualbox

elif [[ $1 == "generic-vmware" || $1 == "generic-vmware.json" ]]; then build generic-vmware
elif [[ $1 == "generic-libvirt" || $1 == "generic-libvirt.json" ]]; then build generic-libvirt
elif [[ $1 == "generic-hyperv" || $1 == "generic-hyperv.json" ]]; then build generic-hyperv
elif [[ $1 == "generic-virtualbox" || $1 == "generic-virtualbox.json" ]]; then build generic-virtualbox

# Build a specific box.
elif [[ $1 == "box" ]]; then box $2

# The full monty.
elif [[ $1 == "all" ]]; then all

# Catchall
else
	echo ""
	echo " Stages"
	echo $"  `basename $0` {start|links|validate|missing|available|cleanup} or "
	echo ""
	echo " Groups"
	echo $"  `basename $0` {magma|generic}"
  echo ""
  echo " Global"
	echo $"  `basename $0` {all}"
	echo ""
	echo " Please select a target and run this command again."
	echo ""
	exit 2
fi

# Upload to the website.
#pscp -i ~/Data/Putty/root-virtual.lavabit.com.priv.ppk magma-centos-*-0.*.box root@osheana.virtual.lavabit.com:/var/www/html/downloads/
