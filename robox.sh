#!/bin/bash

# Name: robox.sh
# Author: Ladar Levison
#
# Description: Used to build various virtual machines using packer.

# Status
# OpenBSD needs guest agent install scripts.

# Version Information
export VERSION="1.6.26"
export AGENT="Vagrant/2.1.1 (+https://www.vagrantup.com; ruby2.4.4):"

# Limit the number of cpus packer will use.
export GOMAXPROCS="2"

# Ensure a consistent working directory so relative paths work.
pushd `dirname $0` > /dev/null
BASE=`pwd -P`
popd > /dev/null
cd $BASE

# Credentials and tokens.
if [ ! -f $BASE/.credentialsrc ]; then
cat << EOF > $BASE/.credentialsrc
#!/bin/bash
export GOMAXPROCS="2"
export DOCKER_USER="LOGIN"
export DOCKER_EMAIL="EMAIL"
export DOCKER_PASSWORD="PASSWORD"
export VMWARE_WORKSTATION="SERIAL"
export VAGRANT_CLOUD_TOKEN="TOKEN"

# Overrides the Repo Box Version
VERSION="1.0.0"
EOF
fi

# Import the credentials.
source $BASE/.credentialsrc

# The list of packer config files.
FILES="magma-docker.json "\
"magma-hyperv.json magma-vmware.json magma-libvirt.json magma-virtualbox.json "\
"generic-hyperv.json generic-vmware.json generic-libvirt.json generic-parallels.json generic-virtualbox.json "\
"lineage-hyperv.json lineage-vmware.json lineage-libvirt.json lineage-virtualbox.json "\
"developer-hyperv.json developer-vmware.json developer-libvirt.json developer-virtualbox.json"

# Collect the list of ISO urls.
ISOURLS=(`grep -E "iso_url|guest_additions_url" $FILES | grep -v -E "res/media/ubuntu-18.10-server-amd64.iso|res/media/rhel-server-6.9-x86_64-dvd.iso|res/media/rhel-server-7.5-x86_64-dvd.iso" | awk -F'"' '{print $4}'`)
ISOSUMS=(`grep -E "iso_checksum|guest_additions_sha256" $FILES | grep -v "iso_checksum_type" | grep -v -E "4836e45bda018a3d99aca40599150735e15a070f21ee287dead360acff2841b4|3f961576e9f81ea118566f73f98d7bdf3287671c35436a13787c1ffd5078cf8e|d0dd6ae5e001fb050dafefdfd871e7e648b147fb2d35f0e106e0b34a0163e8f5" | awk -F'"' '{print $4}'`)

# Collect the list of box names.
MAGMA_BOXES=`grep -E '"name":' $FILES | awk -F'"' '{print $4}' | grep "magma-" | sort --field-separator=- -k 3i -k 2.1,2.0`
GENERIC_BOXES=`grep -E '"name":' $FILES | awk -F'"' '{print $4}' | grep "generic-" | sort --field-separator=- -k 3i -k 2.1,2.0`
LINEAGE_BOXES=`grep -E '"name":' $FILES | awk -F'"' '{print $4}' | grep -E "lineage-|lineageos-" | sort --field-separator=- -k 1i,1.8 -k 3i -k 2i,2.4`
BOXES="$GENERIC_BOXES $MAGMA_BOXES $LINEAGE_BOXES"

# Collect the list of box tags.
MAGMA_TAGS=`grep -E '"box_tag":' $FILES | awk -F'"' '{print $4}' | grep "magma" | sort -u --field-separator=-`
ROBOXES_TAGS=`grep -E '"box_tag":' $FILES | awk -F'"' '{print $4}' | grep "roboxes" | sort -u --field-separator=-`
GENERIC_TAGS=`grep -E '"box_tag":' $FILES | awk -F'"' '{print $4}' | grep "generic" | sort -u --field-separator=-`
LINEAGE_TAGS=`grep -E '"box_tag":' $FILES | awk -F'"' '{print $4}' | grep "lineage" | sort -u --field-separator=-`
TAGS="$GENERIC_TAGS $ROBOXES_TAGS $MAGMA_TAGS $LINEAGE_TAGS"

# These boxes aren't publicly available yet, so we filter them out of available test.
FILTERED_TAGS="lavabit/magma-alpine lavabit/magma-arch lavabit/magma-freebsd lavabit/magma-gentoo lavabit/magma-openbsd"

# A list of configs to skip during complete build operations.
export EXCEPTIONS=""

function start() {
  # Disable IPv6 or the VMware builder won't be able to load the Kick Start configuration.
  sudo sysctl net.ipv6.conf.all.disable_ipv6=1

  # Start the required services.
  # sudo systemctl restart vmtoolsd.service
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

  # Confirm the VirtualBox kernel modules loaded.
  if [ -f /usr/lib/virtualbox/vboxdrv.sh ]; then
    /usr/lib/virtualbox/vboxdrv.sh status | grep --color=none "VirtualBox kernel modules \(.*\) are loaded."
    if [ $? != 0 ]; then
      sudo /usr/lib/virtualbox/vboxdrv.sh setup
      if [ $? != 0 ]; then
        tput setaf 1; tput bold; printf "\n\nThe virtualbox kernel modules failed to load properly...\n\n"; tput sgr0
        for i in 1 2 3; do printf "\a"; sleep 1; done
        exit 1
      fi
    fi
  fi

  # Set the tuning profile to virtual-host.
  if [ -f /usr/sbin/tuned-adm ]; then
    sudo /usr/sbin/tuned-adm profile virtual-host
    sudo /usr/sbin/tuned-adm active
  fi

  # Set the CPU performance level to maximum.
  if [ -f /usr/bin/cpupower ]; then
    sudo /usr/bin/cpupower set -b 0
    sudo /usr/bin/cpupower info
  fi
}

# Print the current URL and SHA hash for install discs which are updated frequently.
function isos {
  tput setaf 2; printf "\nArch\n\n"; tput sgr0;
  URL="https://mirrors.edge.kernel.org/archlinux/iso/latest/"
  ISO=`curl --silent "${URL}" | grep --invert-match sha256 | grep --extended-regexp --only-matching --max-count=1 "archlinux\-[0-9]{4}\.[0-9]{2}\.[0-9]{2}\-x86\_64\.iso" | uniq`
  URL="${URL}${ISO}"
  SHA=`curl --silent "${URL}" | sha256sum | awk -F' ' '{print $1}'`
  printf "${URL}\n${SHA}\n\n"

  tput setaf 2; printf "\nGentoo\n\n"; tput sgr0;
  URL="https://mirrors.kernel.org/gentoo/releases/amd64/autobuilds/current-install-amd64-minimal/"
  ISO=`curl --silent "${URL}" | grep --invert-match sha256 | grep --extended-regexp --only-matching --max-count=1 "install\-amd64\-minimal\-[0-9]{8}T[0-9]{6}Z\.iso" | uniq`
  URL="${URL}${ISO}"
  SHA=`curl --silent "${URL}" | sha256sum | awk -F' ' '{print $1}'`
  printf "${URL}\n${SHA}\n\n"

  # tput setaf 2; printf "\nOpenSUSE\n\n"; tput sgr0;
  # URL="https://mirrors.kernel.org/opensuse/distribution/leap/42.3/iso/"
  # ISO=`curl --silent "${URL}" | grep --invert-match sha256 | grep --extended-regexp --only-matching --max-count=1 "openSUSE\-Leap\-42\.3\-NET\-x86\_64\-Build[0-9]{4}\-Media.iso|openSUSE\-Leap\-42\.3\-NET\-x86\_64.iso" | uniq`
  # URL="${URL}${ISO}"
  # SHA=`curl --silent "${URL}" | sha256sum | awk -F' ' '{print $1}'`
  # printf "${URL}\n${SHA}\n\n"

  tput setaf 2; printf "\nUbuntu\n\n"; tput sgr0;
  URL="http://cdimage.ubuntu.com/ubuntu-server/daily/pending/"
  ISO=`curl --silent "${URL}" | grep --invert-match sha256 | grep --extended-regexp --only-matching --max-count=1 "cosmic-server-amd64.iso" | uniq`
  URL="${URL}${ISO}"
  SHA=`curl --silent "${URL}" | sha256sum | awk -F' ' '{print $1}'`
  printf "${URL}\n${SHA}\n\n"
}

function cache {

  unset PACKER_LOG
  packer build -on-error=cleanup -parallel=false packer-cache.json 2>&1 | grep --color=none -E "Download progress|Downloading or copying"

  if [[ $? != 0 ]]; then
    tput setaf 1; tput bold; printf "\n\nDistro disc image download aborted...\n\n"; tput sgr0
  else
    tput setaf 2; tput bold; printf "\n\nDistro disc images have finished downloading...\n\n"; tput sgr0
  fi

}

# Verify all of the ISO locations are still valid.
function verify_url {

  # Grab just the response header and look for the 200 response code to indicate the link is valid.
  curl --silent --location --head "$1" | head -1 | grep --silent --extended-regexp "HTTP/1\.1 200 OK|HTTP/2\.0 200 OK"

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
    printf "Expected    -  $2\n\n"
    exit 1
  fi

  printf "Validated   :  $1\n"
  return 0
}

# Verify the local ISO files are valid and if necessary download the file.
function verify_local {

  ISOAGENT="Mozilla/5.0 (X11; Linux x86_64; rv:52.0) Gecko/20100101 Firefox/52.0"

  # Make sure the ISO exists, and is the proper size.
  if [ ! -f "${3}" ] || [ `du --bytes "${3}" | awk -F' ' '{print $1}'` != ${1} ]; then
    curl --location --retry 16 --retry-delay 16 --max-redirs 16 --user-agent "${ISOAGENT}" --output "${3}.part" "${4}"
    sha256sum "${3}.part" | grep --silent "${2}"
    if [ $? != 0 ]; then
      tput setaf 1; tput bold; printf "\n\nUbuntu 18.10 could not be downloaded...\n\n"; tput sgr0
      rm --force "${3}"
    else
      mv --force "${3}.part" "${3}"
    fi
  fi
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

  packer build -on-error=cleanup -parallel=false -except="${EXCEPTIONS}" $1.json

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
  export PACKER_LOG_PATH="$BASE/logs/log-${TIMESTAMP}.txt"

  if [[ $OS == "Windows_NT" ]]; then
      packer build -on-error=cleanup -parallel=false -only=$1 magma-hyerpv.json
      packer build -on-error=cleanup -parallel=false -only=$1 generic-hyerpv.json
      packer build -on-error=cleanup -parallel=false -only=$1 lineage-hyperv.json
      packer build -on-error=cleanup -parallel=false -only=$1 developer-hyperv.json
  elif [[ `uname` == "Darwin" ]]; then
      packer build -on-error=cleanup -parallel=false -only=$1 generic-parallels.json
  else
      packer build -on-error=cleanup -parallel=false -only=$1 magma-docker.json
      packer build -on-error=cleanup -parallel=false -only=$1 magma-vmware.json
      packer build -on-error=cleanup -parallel=false -only=$1 magma-libvirt.json
      packer build -on-error=cleanup -parallel=false -only=$1 magma-virtualbox.json
      packer build -on-error=cleanup -parallel=false -only=$1 generic-vmware.json
      packer build -on-error=cleanup -parallel=false -only=$1 generic-libvirt.json
      packer build -on-error=cleanup -parallel=false -only=$1 generic-virtualbox.json
      packer build -on-error=cleanup -parallel=false -only=$1 developer-vmware.json
      packer build -on-error=cleanup -parallel=false -only=$1 developer-libvirt.json
      packer build -on-error=cleanup -parallel=false -only=$1 developer-virtualbox.json
      packer build -on-error=cleanup -parallel=false -only=$1 lineage-vmware.json
      packer build -on-error=cleanup -parallel=false -only=$1 lineage-libvirt.json
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
  verify_json packer-cache
  verify_json magma-docker
  verify_json magma-hyperv
  verify_json magma-vmware
  verify_json magma-libvirt
  verify_json magma-virtualbox
  verify_json generic-hyperv
  verify_json generic-vmware
  verify_json generic-libvirt
  verify_json generic-parallels
  verify_json generic-virtualbox
  verify_json developer-hyperv
  verify_json developer-vmware
  verify_json developer-libvirt
  verify_json developer-virtualbox
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

    FOUND=0
    MISSING=0
    LIST=($TAGS)
    FILTER=($FILTERED_TAGS)

    # Loop through and remove the filtered tags from the list.
    for ((i = 0; i < ${#FILTER[@]}; ++i)); do
      LIST=(${LIST[@]//${FILTER[$i]}})
    done

    for ((i = 0; i < ${#LIST[@]}; ++i)); do
      ORGANIZATION=`echo ${LIST[$i]} | awk -F'/' '{print $1}'`
      BOX=`echo ${LIST[$i]} | awk -F'/' '{print $2}'`

      PROVIDER="hyperv"
      curl --head --silent --location --user-agent '${AGENT}' "https://app.vagrantup.com/${ORGANIZATION}/boxes/${BOX}/versions/${VERSION}/providers/${PROVIDER}.box?access_token=${VAGRANT_CLOUD_TOKEN}" | head -1 | grep --silent --extended-regexp "HTTP/1\.1 200 OK|HTTP/2\.0 200 OK|HTTP/1\.1 302 Found|HTTP/2.0 302 Found"

      if [ $? != 0 ]; then
        let MISSING+=1
        printf "Box  -  "; tput setaf 1; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
      else
        let FOUND+=1
        printf "Box  +  "; tput setaf 2; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
      fi

      PROVIDER="libvirt"
      curl --head --silent --location --user-agent '${AGENT}' "https://app.vagrantup.com/${ORGANIZATION}/boxes/${BOX}/versions/${VERSION}/providers/${PROVIDER}.box?access_token=${VAGRANT_CLOUD_TOKEN}" | head -1 | grep --silent --extended-regexp "HTTP/1\.1 200 OK|HTTP/2\.0 200 OK|HTTP/1\.1 302 Found|HTTP/2.0 302 Found"

      if [ $? != 0 ]; then
        let MISSING+=1
        printf "Box  -  "; tput setaf 1; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
      else
        let FOUND+=1
        printf "Box  +  "; tput setaf 2; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
      fi

      PROVIDER="parallels"
      if [[ "${ORGANIZATION}" == "generic" ]]; then
        curl --head --silent --location --user-agent '${AGENT}' "https://app.vagrantup.com/${ORGANIZATION}/boxes/${BOX}/versions/${VERSION}/providers/${PROVIDER}.box?access_token=${VAGRANT_CLOUD_TOKEN}" | head -1 | grep --silent --extended-regexp "HTTP/1\.1 200 OK|HTTP/2\.0 200 OK|HTTP/1\.1 302 Found|HTTP/2.0 302 Found"

        if [ $? != 0 ]; then
          let MISSING+=1
          printf "Box  -  "; tput setaf 1; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
        else
          let FOUND+=1
          printf "Box  +  "; tput setaf 2; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
        fi
      fi

      PROVIDER="virtualbox"
      curl --head --silent --location --user-agent '${AGENT}' "https://app.vagrantup.com/${ORGANIZATION}/boxes/${BOX}/versions/${VERSION}/providers/${PROVIDER}.box?access_token=${VAGRANT_CLOUD_TOKEN}" | head -1 | grep --silent --extended-regexp "HTTP/1\.1 200 OK|HTTP/2\.0 200 OK|HTTP/1\.1 302 Found|HTTP/2.0 302 Found"

      if [ $? != 0 ]; then
        let MISSING+=1
        printf "Box  -  "; tput setaf 1; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
      else
        let FOUND+=1
        printf "Box  +  "; tput setaf 2; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
      fi

      PROVIDER="vmware_desktop"
      curl --head --silent --location --user-agent '${AGENT}' "https://app.vagrantup.com/${ORGANIZATION}/boxes/${BOX}/versions/${VERSION}/providers/${PROVIDER}.box?access_token=${VAGRANT_CLOUD_TOKEN}" | head -1 | grep --silent --extended-regexp "HTTP/1\.1 200 OK|HTTP/2\.0 200 OK|HTTP/1\.1 302 Found|HTTP/2.0 302 Found"

      if [ $? != 0 ]; then
        let MISSING+=1
        printf "Box  -  "; tput setaf 1; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
      else
        let FOUND+=1
        printf "Box  +  "; tput setaf 2; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
      fi
    done

    # Get the totla number of boxes.
    let TOTAL=${FOUND}+${MISSING}
    let FOUND=${TOTAL}-${MISSING}

    # Let the user know how many boxes were missing.
    if [ $MISSING -eq 0 ]; then
      printf "\nAll ${TOTAL} of the boxes are available...\n\n"
    else
      printf "\nOf the ${TOTAL} boxes defined, and ${FOUND} are privately available, while ${MISSING} are unavailable...\n\n"
    fi
}

function public() {

    FOUND=0
    MISSING=0
    LIST=($TAGS)
    FILTER=($FILTERED_TAGS)

    # Loop through and remove the filtered tags from the list.
    for ((i = 0; i < ${#FILTER[@]}; ++i)); do
      LIST=(${LIST[@]//${FILTER[$i]}})
    done

    for ((i = 0; i < ${#LIST[@]}; ++i)); do
      ORGANIZATION=`echo ${LIST[$i]} | awk -F'/' '{print $1}'`
      BOX=`echo ${LIST[$i]} | awk -F'/' '{print $2}'`

      PROVIDER="hyperv"
      curl --head --silent --location --user-agent '${AGENT}' "https://app.vagrantup.com/${ORGANIZATION}/boxes/${BOX}/versions/${VERSION}/providers/${PROVIDER}.box" | head -1 | grep --silent --extended-regexp "HTTP/1\.1 200 OK|HTTP/2\.0 200 OK|HTTP/1\.1 302 Found|HTTP/2.0 302 Found"

      if [ $? != 0 ]; then
        let MISSING+=1
        printf "Box  -  "; tput setaf 1; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
      else
        let FOUND+=1
        printf "Box  +  "; tput setaf 2; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
      fi

      PROVIDER="libvirt"
      curl --head --silent --location --user-agent '${AGENT}' "https://app.vagrantup.com/${ORGANIZATION}/boxes/${BOX}/versions/${VERSION}/providers/${PROVIDER}.box" | head -1 | grep --silent --extended-regexp "HTTP/1\.1 200 OK|HTTP/2\.0 200 OK|HTTP/1\.1 302 Found|HTTP/2.0 302 Found"

      if [ $? != 0 ]; then
        let MISSING+=1
        printf "Box  -  "; tput setaf 1; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
      else
        let FOUND+=1
        printf "Box  +  "; tput setaf 2; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
      fi

      PROVIDER="parallels"
      if [[ "${ORGANIZATION}" =~ ^(generic|roboxes)$ ]]; then
        curl --head --silent --location --user-agent '${AGENT}' "https://app.vagrantup.com/${ORGANIZATION}/boxes/${BOX}/versions/${VERSION}/providers/${PROVIDER}.box" | head -1 | grep --silent --extended-regexp "HTTP/1\.1 200 OK|HTTP/2\.0 200 OK|HTTP/1\.1 302 Found|HTTP/2.0 302 Found"

        if [ $? != 0 ]; then
          let MISSING+=1
          printf "Box  -  "; tput setaf 1; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
        else
          let FOUND+=1
          printf "Box  +  "; tput setaf 2; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
        fi
      fi

      PROVIDER="virtualbox"
      curl --head --silent --location --user-agent '${AGENT}' "https://app.vagrantup.com/${ORGANIZATION}/boxes/${BOX}/versions/${VERSION}/providers/${PROVIDER}.box" | head -1 | grep --silent --extended-regexp "HTTP/1\.1 200 OK|HTTP/2\.0 200 OK|HTTP/1\.1 302 Found|HTTP/2.0 302 Found"

      if [ $? != 0 ]; then
        let MISSING+=1
        printf "Box  -  "; tput setaf 1; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
      else
        let FOUND+=1
        printf "Box  +  "; tput setaf 2; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
      fi

      PROVIDER="vmware_desktop"
      curl --head --silent --location --user-agent '${AGENT}' "https://app.vagrantup.com/${ORGANIZATION}/boxes/${BOX}/versions/${VERSION}/providers/${PROVIDER}.box" | head -1 | grep --silent --extended-regexp "HTTP/1\.1 200 OK|HTTP/2\.0 200 OK|HTTP/1\.1 302 Found|HTTP/2.0 302 Found"

      if [ $? != 0 ]; then
        let MISSING+=1
        printf "Box  -  "; tput setaf 1; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
      else
        let FOUND+=1
        printf "Box  +  "; tput setaf 2; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
      fi
    done

    # Get the totla number of boxes.
    let TOTAL=${FOUND}+${MISSING}
    let FOUND=${TOTAL}-${MISSING}

    # Let the user know how many boxes were missing.
    if [ $MISSING -eq 0 ]; then
      printf "\nAll ${TOTAL} of the boxes are available...\n\n"
    else
      printf "\nOf the ${TOTAL} boxes defined, ${FOUND} are publicly available, while ${MISSING} are unavailable...\n\n"
    fi
}

function localized() {
  verify_local 746586112 4836e45bda018a3d99aca40599150735e15a070f21ee287dead360acff2841b4 res/media/ubuntu-18.10-server-amd64.iso http://cdimage.ubuntu.com/ubuntu-server/daily/20180611/cosmic-server-amd64.iso
  verify_local 3887071232 3f961576e9f81ea118566f73f98d7bdf3287671c35436a13787c1ffd5078cf8e res/media/rhel-server-6.9-x86_64-dvd.iso https://archive.org/download/rhel-server-6.9-x86_64-dvd/rhel-server-6.9-x86_64-dvd.iso
  verify_local 4617928704 d0dd6ae5e001fb050dafefdfd871e7e648b147fb2d35f0e106e0b34a0163e8f5 res/media/rhel-server-7.5-x86_64-dvd.iso https://archive.org/download/rhel-server-7.5-x86_64-dvd/rhel-server-7.5-x86_64-dvd.iso
}

function cleanup() {
  rm -rf $BASE/packer_cache/ $BASE/output/ $BASE/logs/
}

function docker-login() {
  docker login -u "$DOCKER_USER" -p "$DOCKER_PASSWORD"
  if [[ $? != 0 ]]; then
    tput setaf 1; tput bold; printf "\n\nThe docker login credentials failed.\n\n"; tput sgr0
    exit 1
  fi
}

function docker-logout() {
  docker logout
  if [[ $? != 0 ]]; then
    tput setaf 1; tput bold; printf "\n\nThe docker logout command failed.\n\n"; tput sgr0
    exit 1
  fi
}

function magma() {
  if [[ $OS == "Windows_NT" ]]; then
    build magma-hyperv
  else
    build magma-vmware
    build magma-libvirt
    build magma-virtualbox

    docker-login ; build magma-docker; docker-logout
  fi
}

function generic() {
  if [[ $OS == "Windows_NT" ]]; then
    build generic-hyperv
  elif [[ `uname` == "Darwin" ]]; then
    build generic-parallels
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

function developer() {
  if [[ $OS == "Windows_NT" ]]; then
    build developer-hyperv
  else
    build developer-vmware
    build developer-libvirt
    build developer-virtualbox
  fi
}

function vmware() {
  verify_json generic-vmware
  verify_json magma-vmware
  verify_json developer-vmware
  verify_json lineage-vmware

  build generic-vmware
  build magma-vmware
  build developer-vmware
  build lineage-vmware
}

function hyperv() {

  if [[ $OS == "Windows_NT" ]]; then

    LIST=($BOXES)

    verify_json generic-hyperv
    verify_json magma-hyperv
    verify_json developer-hyperv
    verify_json lineage-hyperv

    # Build the generic boxes first.
    for ((i = 0; i < ${#LIST[@]}; ++i)); do
      if [[ "${LIST[$i]}" =~ ^generic-[a-z]*[0-9]*-hyperv$ ]]; then
        packer build -parallel=false -except="${EXCEPTIONS}" -only="${LIST[$i]}" generic-hyperv.json
        rm -f $BASE/output/"${LIST[$i]}-${VERSION}.box"
      fi
    done

    # Build the magma boxes second.
    for ((i = 0; i < ${#LIST[@]}; ++i)); do
      if [[ "${LIST[$i]}" =~ ^magma-hyperv$ ]]; then
        packer build -parallel=false -except="${EXCEPTIONS}" -only="${LIST[$i]}" magma-hyperv.json
        rm -f $BASE/output/"${LIST[$i]}-${VERSION}.box"
      fi
    done
    for ((i = 0; i < ${#LIST[@]}; ++i)); do
      if [[ "${LIST[$i]}" =~ ^magma-[a-z]*[0-9]*-hyperv$ ]] && [[ "${LIST[$i]}" != ^magma-developer-hyperv$ ]]; then
        packer build -parallel=false -except="${EXCEPTIONS}" -only="${LIST[$i]}" magma-hyperv.json
        rm -f $BASE/output/"${LIST[$i]}-${VERSION}.box"
      fi
    done
    for ((i = 0; i < ${#LIST[@]}; ++i)); do
      if [[ "${LIST[$i]}" == ^magma-developer-hyperv$ ]]; then
        packer build -parallel=false -except="${EXCEPTIONS}" -only="${LIST[$i]}" developer-hyperv.json
        rm -f $BASE/output/"${LIST[$i]}-${VERSION}.box"
      fi
    done

    # Build the Lineage boxes fourth.
    for ((i = 0; i < ${#LIST[@]}; ++i)); do
      if [[ "${LIST[$i]}" =~ ^(lineage|lineageos)-hyperv$ ]]; then
        packer build -parallel=false -except="${EXCEPTIONS}" -only="${LIST[$i]}" lineage-hyperv.json
        rm -f $BASE/output/"${LIST[$i]}-${VERSION}.box"
      fi
    done
    for ((i = 0; i < ${#LIST[@]}; ++i)); do
      if [[ "${LIST[$i]}" =~ ^(lineage|lineageos)-[a-z]*[0-9]*-hyperv$ ]]; then
        packer build -parallel=false -except="${EXCEPTIONS}" -only="${LIST[$i]}" lineage-hyperv.json
        rm -f $BASE/output/"${LIST[$i]}-${VERSION}.box"
      fi
    done

  else
    tput setaf 1; tput bold; printf "\n\nThe HyperV roboxes require a Windows host...\n\n"; tput sgr0
  fi
}

function libvirt() {
  verify_json generic-libvirt
  verify_json magma-libvirt
  verify_json developer-libvirt
  verify_json lineage-libvirt

  build generic-libvirt
  build magma-libvirt
  build developer-libvirt
  build lineage-libvirt
}

function parallels() {
  if [[ `uname` == "Darwin" ]]; then

    # Ideally, we run this. However our Mac is resource starved
    # so we need to build each box individually.
    # build generic-parallels

    LIST=($BOXES)

    verify_json generic-parallels

    for ((i = 0; i < ${#LIST[@]}; ++i)); do
      if [[ "${LIST[$i]}" =~ ^(generic|magma)-[a-z]*[0-9]*-parallels$ ]]; then
        packer build -parallel=false -except="${EXCEPTIONS}" -only="${LIST[$i]}" generic-parallels.json
        rm -rf $BASE/output/ $BASE/packer_cache/
      fi
    done

  else
    tput setaf 1; tput bold; printf "\n\nThe Parallels roboxes require a MacOS X host...\n\n"; tput sgr0
  fi
}

function virtualbox() {
  verify_json generic-virtualbox
  verify_json magma-virtualbox
  verify_json developer-virtualbox
  verify_json lineage-virtualbox

  build generic-virtualbox
  build magma-virtualbox
  build developer-virtualbox
  build lineage-virtualbox
}

function builder() {
  generic
  magma
  developer
  lineage
}

function all() {
  links
  validate
  localized

  start
  builder

  for i in 1 2 3 4 5 6 7 8 9 10; do printf "\a"; sleep 1; done
}

# The stage functions.
if [[ $1 == "start" ]]; then start
elif [[ $1 == "links" ]]; then links
elif [[ $1 == "cache" ]]; then cache
elif [[ $1 == "validate" ]]; then validate
elif [[ $1 == "build" ]]; then builder
elif [[ $1 == "cleanup" ]]; then cleanup

# The type functions.
elif [[ $1 == "vmware" ]]; then vmware
elif [[ $1 == "hyperv" ]]; then hyperv
elif [[ $1 == "docker" ]]; then verify_json magma-docker ; docker-login ; build magma-docker ; docker-logout
elif [[ $1 == "libvirt" ]]; then libvirt
elif [[ $1 == "parallels" ]]; then parallels
elif [[ $1 == "virtualbox" ]]; then virtualbox

# The helper functions.
elif [[ $1 == "isos" ]]; then isos
elif [[ $1 == "sums" ]]; then sums
elif [[ $1 == "local" ]]; then localized
elif [[ $1 == "missing" ]]; then missing
elif [[ $1 == "public" ]]; then public
elif [[ $1 == "available" ]]; then available

# The group builders.
elif [[ $1 == "magma" ]]; then magma
elif [[ $1 == "generic" ]]; then generic
elif [[ $1 == "lineage" ]]; then lineage
elif [[ $1 == "developer" ]]; then developer

# The file builders.
elif [[ $1 == "magma-vmware" || $1 == "magma-vmware.json" ]]; then build magma-vmware
elif [[ $1 == "magma-hyperv" || $1 == "magma-hyperv.json" ]]; then build magma-hyperv
elif [[ $1 == "magma-libvirt" || $1 == "magma-libvirt.json" ]]; then build magma-libvirt
elif [[ $1 == "magma-virtualbox" || $1 == "magma-virtualbox.json" ]]; then build magma-virtualbox
elif [[ $1 == "magma-docker" || $1 == "magma-docker.json" ]]; then verify_json magma-docker ; docker-login ; build magma-docker ; docker-logout

elif [[ $1 == "developer-vmware" || $1 == "developer-vmware.json" ]]; then build developer-vmware
elif [[ $1 == "developer-hyperv" || $1 == "developer-hyperv.json" ]]; then build developer-hyperv
elif [[ $1 == "developer-libvirt" || $1 == "developer-libvirt.json" ]]; then build developer-libvirt
elif [[ $1 == "developer-virtualbox" || $1 == "developer-virtualbox.json" ]]; then build developer-virtualbox

elif [[ $1 == "generic-vmware" || $1 == "generic-vmware.json" ]]; then build generic-vmware
elif [[ $1 == "generic-hyperv" || $1 == "generic-hyperv.json" ]]; then build generic-hyperv
elif [[ $1 == "generic-libvirt" || $1 == "generic-libvirt.json" ]]; then build generic-libvirt
elif [[ $1 == "generic-parallels" || $1 == "generic-parallels.json" ]]; then build generic-parallels
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
  echo $"  `basename $0` {start|validate|build|cleanup} or"
  echo ""
  echo " Types"
  echo $"  `basename $0` {vmware|hyperv|libvirt|docker|parallels|virtualbox} or"
  echo ""
  echo " Groups"
  echo $"  `basename $0` {magma|generic|lineage|developer} or"
  echo ""
  echo " Media"
  echo $"  `basename $0` {isos|sums|links|local|cache} or"
  echo ""
  echo " Helpers"
  echo $"  `basename $0` {missing|public|available} or"
  echo ""
  echo " Boxes"
  echo $"  `basename $0` {box NAME} or"
  echo ""
  echo " Global"
  echo $"  `basename $0` {all}"
  echo ""
  echo " Please select a target and run this command again."
  echo ""
  exit 2
fi
