#!/bin/bash

export VERSION="0.8.27"
export DOCKER_USER="ladar"
export DOCKER_EMAIL="ladar@lavabitllc.com"
export DOCKER_PASSWORD="Fs2q5aGWNp6h^^N7qfhH"
export ATLAS_TOKEN="qyToIsMKMP9P0w.atlasv1.MiyPtcThL0y4Fwk53lFri83nOEt1rUDSQNW2CxFbxJtFd7llvllpqSL176pTkeFVfiE"

LINK=`readlink -f $0`
BASE=`dirname $LINK`

cd $BASE

# Disable IPv6 or the VMware builder won't be able to load the Kick Start configuration.
sudo sysctl net.ipv6.conf.all.disable_ipv6=1

# Start the required services.
sudo systemctl restart vmtoolsd.service
sudo systemctl restart vboxdrv.service
sudo systemctl restart libvirtd.service
sudo systemctl restart docker-latest.service
sudo systemctl restart vmware.service vmware-USBArbitrator.service vmware-workstation-server.service

# Validate the templates before building.
validate() {
  packer validate $1.json
  if [[ $? != 0 ]]; then
    tput setaf 1; tput bold; printf "\n\nthe $1 packer template failed to validate...\n\n"; tput sgr0
    for i in 1 2 3; do printf "\a"; sleep 1; done
    exit 1
  fi
}

# Verify all of the ISO locations are still valid.
function verify {

  # Grab just the response header and look for the 200 response code to indicate the link is valid.
  curl --silent --head "$1" | head -1 | grep --silent --extended-regexp "HTTP/1\.1 200 OK|HTTP/2\.0 200 OK"

  # The grep return code tells us whether it found a match in the header or not.
  if [ $? != 0 ]; then
    printf "Link Failure:  $1\n\n"
    exit 1
  fi

  # # Grab the ISO and pipe the data through sha256sum, then compare the checksum value.
  # curl --silent "$1" | sha256sum | grep --silent "$2"
  #
  # # The grep return code tells us whether it found a match in the header or not.
  # if [ $? != 0 ]; then
  #   SUM=`curl --silent "$1" | sha256sum | awk -F' ' '{print $1}'`
  #   printf "Hash Failure:  $1\n"
  #   printf "Found       -  $SUM\n"
  #   printf "Expected    -  $SUM\n\n"
  #   exit 1
  # fi
  #
  # printf "Validated   :  $1\n"
  # return 0
}

# Build the boxes and cleanup the packer cache after each run.
build() {

  export PACKER_LOG="1"
  export PACKER_LOG_PATH="/home/ladar/Desktop/packer-logs/$1.txt"

  packer build -on-error=cleanup -parallel=false $1.json
  # packer build -on-error=cleanup -except=lineage-libvirt -parallel=false $1.json
  #packer build -on-error=cleanup -parallel=false -only=magma-alpine-vmware,magma-alpine-libvirt,magma-alpine-virtualbox $1.json

  if [[ $? != 0 ]]; then
    tput setaf 1; tput bold; printf "\n\n$1 images failed to build properly...\n\n"; tput sgr0
    for i in 1 2 3; do printf "\a"; sleep 1; done
    # Uncomment to abort the build if a machine fails.
    # rm -rf packer_cache/
    # exit 1
  fi
}

validate magma-docker

validate magma-vmware
validate magma-libvirt
validate magma-virtualbox

validate generic-vmware
validate generic-libvirt
validate generic-virtualbox

# Collect the list of ISO urls.
ISOURLS=(`grep -E "iso_url|guest_additions_url" magma-docker.json magma-libvirt.json magma-vmware.json magma-virtualbox.json generic-libvirt.json generic-vmware.json generic-virtualbox.json | awk -F'"' '{print $4}'`)
ISOSUMS=(`grep -E "iso_checksum|guest_additions_sha256" magma-docker.json magma-libvirt.json magma-vmware.json magma-virtualbox.json generic-libvirt.json generic-vmware.json generic-virtualbox.json | grep -v "iso_checksum_type" | awk -F'"' '{print $4}'`)

for ((i = 0; i < ${#ISOURLS[@]}; ++i)); do
    verify "${ISOURLS[$i]}" "${ISOSUMS[$i]}"
done

# Let the user know all of the links passed.
printf "\nAll ${#ISOURLS[@]} of the install media locations are still valid...\n\n"

#docker login -u "$DOCKER_USER" -p "$DOCKER_PASSWORD"

#build magma-docker

#build magma-vmware
#build magma-libvirt
#build magma-virtualbox

build generic-vmware
build generic-libvirt
build generic-virtualbox

rm -rf packer_cache/

for i in 1 2 3 4 5 6 7 8 9 10; do printf "\a"; sleep 1; done

# Upload to the website.
#pscp -i ~/Data/Putty/root-virtual.lavabit.com.priv.ppk magma-centos-*-0.*.box root@osheana.virtual.lavabit.com:/var/www/html/downloads/
