#!/bin/bash

# Name: robox.sh
# Author: Ladar Levison
#
# Description: Used to build various virtual machines using packer.

# Version Information
[ ! -n "$VERSION" ] && export VERSION="3.2.12"
export AGENT="Vagrant/2.2.9 (+https://www.vagrantup.com; ruby2.6.6)"

# Limit the number of cpus packer will use.
export GOMAXPROCS="2"
export PACKERMAXPROCS="1"

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

# Credentials and tokens.
if [ ! -f $BASE/.credentialsrc ]; then
cat << EOF > $BASE/.credentialsrc
#!/bin/bash
export GOMAXPROCS="2"
export QUAY_USER="LOGIN"
export QUAY_PASSWORD="PASSWORD"
export DOCKER_USER="LOGIN"
export DOCKER_PASSWORD="PASSWORD"
export VMWARE_WORKSTATION="SERIAL"
export VAGRANT_CLOUD_TOKEN="TOKEN"

# Overrides the repo version with a default value.
VERSION="1.0.0"
EOF
tput setaf 1; printf "\n\nCredentials file was missing. Stub file created.\n\n\n"; tput sgr0
sleep 5
fi

# Import the credentials.
source $BASE/.credentialsrc

# The list of packer config files.
FILES="packer-cache.json "\
"magma-docker.json magma-hyperv.json magma-vmware.json magma-libvirt.json magma-virtualbox.json "\
"generic-docker.json generic-hyperv.json generic-vmware.json generic-libvirt.json generic-libvirt-x32.json generic-parallels.json generic-virtualbox.json "\
"lineage-hyperv.json lineage-vmware.json lineage-libvirt.json lineage-virtualbox.json "\
"developer-ova.json developer-hyperv.json developer-vmware.json developer-libvirt.json developer-virtualbox.json"

# Media Files
MEDIAFILES="res/media/rhel-server-6.10-x86_64-dvd.iso"\
"|res/media/rhel-server-7.6-x86_64-dvd.iso"\
"|res/media/rhel-8.0-beta-1-x86_64-dvd.iso"
MEDIASUMS="1e15f9202d2cdd4b2bdf9d6503a8543347f0cb8cc06ba9a0dfd2df4fdef5c727"\
"|60a0be5aeed1f08f2bb7599a578c89ec134b4016cd62a8604b29f15d543a469c"\
"|005d4f88fff6d63b0fc01a10822380ef52570edd8834321de7be63002cc6cc43"
MEDIAURLS="https://archive.org/download/rhel-server-6.10-x86_64-dvd/rhel-server-6.10-x86_64-dvd.iso"\
"|https://archive.org/download/rhel-server-7.6-x86_64-dvd/rhel-server-7.6-x86_64-dvd.iso"\
"|https://archive.org/download/rhel-8.0-x86_64-dvd/rhel-8.0-x86_64-dvd.iso"

# When validating ISO checksums skip these URLS.
DYNAMICURLS="http://cdimage.ubuntu.com/ubuntu-server/daily/current/disco-server-amd64.iso|"\
"https://cdimage.debian.org/cdimage/weekly-builds/amd64/iso-cd/debian-testing-amd64-netinst.iso"

# Collect the list of ISO urls.
ISOURLS=(`grep -E "iso_url|guest_additions_url" $FILES | grep -Ev "$DYNAMICURLS" | awk -F'"' '{print $4}'`)
ISOSUMS=(`grep -E "iso_checksum|guest_additions_sha256" $FILES | awk -F'"' '{print $4}' | sed "s/^sha256://g"`)
UNIQURLS=(`grep -E "iso_url|guest_additions_url" $FILES | awk -F'"' '{print $4}' | sort | uniq`)

# Collect the list of box names.
MAGMA_BOXES=`grep -E '"name":' $FILES | awk -F'"' '{print $4}' | grep "magma-" | sort --field-separator=- -k 3i -k 2.1,2.0`
MAGMA_SPECIAL_BOXES="magma-hyperv magma-vmware magma-libvirt magma-virtualbox magma-docker "\
"magma-centos-hyperv magma-centos-vmware magma-centos-libvirt magma-centos-virtualbox magma-centos-docker "\
"magma-ubuntu-hyperv magma-ubuntu-vmware magma-ubuntu-libvirt magma-ubuntu-virtualbox"
GENERIC_BOXES=`grep -E '"name":' $FILES | awk -F'"' '{print $4}' | grep "generic-" | sort --field-separator=- -k 3i -k 2.1,2.0`
ROBOX_BOXES=`grep -E '"name":' $FILES | awk -F'"' '{print $4}' | grep "generic-" | sed "s/generic-/roboxes-/g"| sort --field-separator=- -k 3i -k 2.1,2.0`
LINEAGE_BOXES=`grep -E '"name":' $FILES | awk -F'"' '{print $4}' | grep -E "lineage-" | sort --field-separator=- -k 1i,1.8 -k 3i -k 2i,2.4`
LINEAGEOS_BOXES=`grep -E '"name":' $FILES | awk -F'"' '{print $4}' | grep -E "lineage-" | sed "s/lineage-/lineageos-/g"| sort --field-separator=- -k 1i,1.8 -k 3i -k 2i,2.4`
MAGMA_BOXES=`echo $MAGMA_SPECIAL_BOXES $MAGMA_BOXES | sed 's/ /\n/g' | sort -u --field-separator=- -k 3i -k 2.1,2.0`
BOXES="$GENERIC_BOXES $ROBOX_BOXES $MAGMA_BOXES $LINEAGE_BOXES $LINEAGEOS_BOXES"

# Collect the list of box tags.
MAGMA_TAGS=`grep -E '"name":' $FILES | awk -F'"' '{print $4}' | grep "magma" | grep -v "magma-developer-ova" | sed "s/magma-/lavabit\/magma-/g" | sed "s/alpine36/alpine/g" | sed "s/debian8/debian/g" | sed "s/fedora27/fedora/g" | sed "s/freebsd11/freebsd/g" | sed "s/openbsd6/openbsd/g" | sed "s/\(-hyperv\|-vmware\|-libvirt\|-parallels\|-virtualbox\|-docker\)\$//g" | sort -u --field-separator=-`
MAGMA_SPECIAL_TAGS="lavabit/magma lavabit/magma-centos lavabit/magma-ubuntu"
ROBOX_TAGS=`grep -E '"name":' $FILES | awk -F'"' '{print $4}' | grep "generic" | sed "s/generic-/roboxes\//g" | sed "s/\(-hyperv\|-vmware\|-x32-libvirt\|-libvirt\|-parallels\|-virtualbox\|-docker\)\$//g" | sort -u --field-separator=-`
GENERIC_TAGS=`grep -E '"name":' $FILES | awk -F'"' '{print $4}' | grep "generic" | sed "s/generic-/generic\//g" | sed "s/\(-hyperv\|-vmware\|-x32-libvirt\|-libvirt\|-parallels\|-virtualbox\|-docker\)//g" | sort -u --field-separator=-`
LINEAGE_TAGS=`grep -E '"name":' $FILES | awk -F'"' '{print $4}' | grep "lineage" | sed "s/lineage-/lineage\/lineage-/g" | sed "s/\(-hyperv\|-vmware\|-libvirt\|-parallels\|-virtualbox\|-docker\)\$//g" |  sort -u --field-separator=-`
LINEAGEOS_TAGS=`grep -E '"name":' $FILES | awk -F'"' '{print $4}' | grep "lineage" | sed "s/lineage-/lineageos\/lineage-/g" | sed "s/\(-hyperv\|-vmware\|-libvirt\|-parallels\|-virtualbox\|-docker\)\$//g" |  sort -u --field-separator=-`
MAGMA_TAGS=`echo $MAGMA_SPECIAL_TAGS $MAGMA_TAGS | sed 's/ /\n/g' | sort -u --field-separator=-`
TAGS="$GENERIC_TAGS $ROBOX_TAGS $MAGMA_TAGS $LINEAGE_TAGS $LINEAGEOS_TAGS"

# These boxes aren't publicly available yet, so we filter them out of available test.
FILTERED_TAGS="lavabit/magma-alpine lavabit/magma-arch lavabit/magma-freebsd lavabit/magma-gentoo lavabit/magma-openbsd"

# A list of configs to skip during complete build operations.
export EXCEPTIONS=""

# Detect Windows subsystem for Linux.
if [ -z $OS ]; then
  if [[ "`uname -r`" =~ -Microsoft$ ]]; then
    export OS="Windows_NT"
  fi
fi

# If Vagrant is installed, use the newer version of curl.
if [ -f /opt/vagrant/embedded/bin/curl ]; then

  export CURL="/opt/vagrant/embedded/bin/curl"

  if [ -f /opt/vagrant/embedded/lib64/libssl.so ] && [ -z LD_PRELOAD ]; then
    export LD_PRELOAD="/opt/vagrant/embedded/lib64/libssl.so"
  elif [ -f /opt/vagrant/embedded/lib64/libssl.so ]; then
    export LD_PRELOAD="/opt/vagrant/embedded/lib64/libssl.so:$LD_PRELOAD"
  fi

  if [ -f /opt/vagrant/embedded/lib64/libcrypto.so ] && [ -z LD_PRELOAD ]; then
    export LD_PRELOAD="/opt/vagrant/embedded/lib64/libcrypto.so"
  elif [ -f /opt/vagrant/embedded/lib64/libcrypto.so ]; then
    export LD_PRELOAD="/opt/vagrant/embedded/lib64/libcrypto.so:$LD_PRELOAD"
  fi

  export LD_LIBRARY_PATH="/opt/vagrant/embedded/bin/lib/:/opt/vagrant/embedded/lib64/"

else
  export CURL="curl"
fi

function retry() {
  local COUNT=1
  local DELAY=1
  local RESULT=0
  while [[ "${COUNT}" -le 10 ]]; do
    [[ "${RESULT}" -ne 0 ]] && {
      tput setaf 1; printf "\n${*} failed... retrying ${COUNT} of 10.\n" >&2; tput sgr0
    }
    "${@}" && { RESULT=0 && break; } || RESULT="${?}"
    COUNT="$((COUNT + 1))"

    # Increase the delay with each iteration.
    DELAY="$((DELAY + 10))"
    sleep $DELAY
  done

  [[ "${COUNT}" -gt 10 ]] && {
    tput setaf 1; printf "\nThe command failed 10 times.\n" >&2; tput sgr0
  }

  return "${RESULT}"
}

function curltry() {
  local COUNT=1
  local DELAY=1
  local RESULT=0
  while [[ "${COUNT}" -le 100 ]]; do
    RESULT=0 ; OUTPUT=`"${@}"` || RESULT="${?}"
    if [[ $RESULT == 0 ]] || [[ `echo "$OUTPUT" | grep --count "404"` == 1 ]]; then
      break
    fi
    COUNT="$((COUNT + 1))"
    DELAY="$((DELAY + 1))"
    sleep $DELAY
  done
  echo "$OUTPUT"
  return "${RESULT}"
}

function start() {
  # Disable IPv6 or the VMware builder won't be able to load the Kick Start configuration.
  sudo sysctl net.ipv6.conf.all.disable_ipv6=1

  # Start the required services.
  # sudo systemctl restart vmtoolsd.service
  if [ -f /usr/lib/systemd/system/vboxdrv.service ]; then sudo systemctl restart vboxdrv.service ; fi
  if [ -f /usr/lib/systemd/system/libvirtd.service ]; then sudo systemctl restart libvirtd.service ; fi
  if [ -f /usr/lib/systemd/system/docker-latest.service ]; then sudo systemctl restart docker-latest.service ;
  elif [ -f /usr/lib/systemd/system/docker.service ]; then sudo systemctl restart docker.service ; fi

  if [ -f /etc/init.d/vmware ]; then sudo /etc/init.d/vmware start ; fi
  if [ -f /etc/init.d/vmware-USBArbitrator ]; then sudo /etc/init.d/vmware-USBArbitrator start ; fi
  if [ -f /etc/init.d/vmware-workstation-server ]; then sudo /etc/init.d/vmware-workstation-server start ; fi

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

function print_iso() {
  SHA=`${CURL} --silent --location "${2}" | sha256sum | awk -F' ' '{print $1}'`
  if [ $? != 0 ]; then
      tput setaf 1; printf "\n$1 failed.\n\n"; tput sgr0; printf "${2}\n\n"
      return 1
  fi
  tput setaf 2; printf "\n$1\n\n"; tput sgr0; printf "${2}\n${SHA}\n\n"
}

# Print the current URL and SHA hash for install discs which are updated frequently.
function isos() {

  # Find the Gentoo URL.
  URL="https://mirrors.kernel.org/gentoo/releases/amd64/autobuilds/current-install-amd64-minimal/"
  ISO=`${CURL} --silent "${URL}" | grep --invert-match sha256 | grep --extended-regexp --only-matching --max-count=1 "install\-amd64\-minimal\-[0-9]{8}T[0-9]{6}Z\.iso" | uniq`
  URL="${URL}${ISO}"
  N=( "${N[@]}" "Gentoo" ); U=( "${U[@]}" "$URL" )

  # Find the Arch URL.
  URL="https://mirrors.edge.kernel.org/archlinux/iso/latest/"
  ISO=`${CURL} --silent "${URL}" | grep --invert-match sha256 | grep --extended-regexp --only-matching --max-count=1 "archlinux\-[0-9]{4}\.[0-9]{2}\.[0-9]{2}\-x86\_64\.iso" | uniq`
  URL="${URL}${ISO}"
  N=( "${N[@]}" "Arch" ); U=( "${U[@]}" "$URL" )

  # Ubuntu Disco
  # URL="http://cdimage.ubuntu.com/ubuntu-server/daily/current/disco-server-amd64.iso"
  # N=( "${N[@]}" "Disco" ); U=( "${U[@]}" "$URL" )

  # Debian Buster
  # URL="https://cdimage.debian.org/cdimage/weekly-builds/amd64/iso-cd/debian-testing-amd64-netinst.iso"
  # N=( "${N[@]}" "Buster" ); U=( "${U[@]}" "$URL" )

  export -f print_iso
  parallel -j 16 --xapply print_iso {1} {2} ::: "${N[@]}" ::: "${U[@]}"

}

function iso() {

  if [ "$1" == "gentoo" ]; then

    # Find the existing Arch URL and hash values.
    ISO_URL=`cat "$BASE/packer-cache.json" | jq -r -c ".builders[] | select( .name | contains(\"gentoo\")) | .iso_url" 2>/dev/null`
    ISO_CHECKSUM=`cat "$BASE/packer-cache.json" | jq  -r -c ".builders[] | select( .name | contains(\"gentoo\")) | .iso_checksum" 2>/dev/null`

    # Find the Gentoo URL.
    URL="https://mirrors.kernel.org/gentoo/releases/amd64/autobuilds/current-install-amd64-minimal/"
    ISO=`${CURL} --fail --silent "${URL}" | grep --invert-match sha256 | grep --extended-regexp --only-matching --max-count=1 "install\-amd64\-minimal\-[0-9]{8}T[0-9]{6}Z\.iso" | uniq`
    if [ $? != 0 ] || [ "$ISO" == "" ]; then
      tput setaf 1; printf "\nThe Gentoo ISO update failed.\n\n"; tput sgr0
      return 1
    fi

    # Calculate the new URL.
    URL="${URL}${ISO}"

    # Download the ISO file and calculate the new hash value.
    set -o pipefail
    SHA=`${CURL} --fail --speed-limit 0 --speed-time 10 --silent --location "${URL}" | sha256sum | awk -F' ' '{print $1}'`
    if [ $? != 0 ] || [ "$SHA" == "" ]; then
        tput setaf 1; printf "\nThe Gentoo ISO update failed.\n\n"; tput sgr0
        return 1
    fi
    set +o pipefail

    # Escape the URL strings.
    URL=`echo $URL | sed "s/\//\\\\\\\\\//g"`
    ISO_URL=`echo $ISO_URL | sed "s/\//\\\\\\\\\//g"`

    # Replace the existing ISO and hash values with the update values.
    sed --in-place "s/$ISO_URL/$URL/g" $FILES
    sed --in-place "s/$ISO_CHECKSUM/sha256:$SHA/g" $FILES


  elif [ "$1" == "arch" ]; then

    # Find the existing Arch URL and hash values.
    ISO_URL=`cat "$BASE/packer-cache.json" | jq -r -c ".builders[] | select( .name | contains(\"arch\")) | .iso_url" 2>/dev/null`
    ISO_CHECKSUM=`cat "$BASE/packer-cache.json" | jq  -r -c ".builders[] | select( .name | contains(\"arch\")) | .iso_checksum" 2>/dev/null`

    # Find the Arch URL.
    URL="https://mirrors.edge.kernel.org/archlinux/iso/latest/"
    ISO=`${CURL} --fail --silent "${URL}" | grep --invert-match sha256 | grep --extended-regexp --only-matching --max-count=1 "archlinux\-[0-9]{4}\.[0-9]{2}\.[0-9]{2}\-x86\_64\.iso" | uniq`
    if [ $? != 0 ] || [ "$ISO" == "" ]; then
      tput setaf 1; printf "\nThe Arch ISO update failed.\n\n"; tput sgr0
      return 1
    fi

    # Calculate the new URL.
    URL="${URL}${ISO}"

    # Download the ISO file and calculate the new hash value.
    set -o pipefail
    SHA=`${CURL} --fail --speed-limit 0 --speed-time 10 --silent --location "${URL}" | sha256sum | awk -F' ' '{print $1}'`
    if [ $? != 0 ] || [ "$SHA" == "" ]; then
        tput setaf 1; printf "\nThe Arch ISO update failed.\n\n"; tput sgr0
        return 1
    fi
    set +o pipefail

    # Escape the URL strings.
    URL=`echo $URL | sed "s/\//\\\\\\\\\//g"`
    ISO_URL=`echo $ISO_URL | sed "s/\//\\\\\\\\\//g"`

    # Replace the existing ISO and hash values with the update values.
    sed --in-place "s/$ISO_URL/$URL/g" $FILES
    sed --in-place "s/$ISO_CHECKSUM/sha256:$SHA/g" $FILES

  fi

}

function cache {

  unset PACKER_LOG ; unset LD_PRELOAD ; unset LD_LIBRARY_PATH ;

  if [[ $OS == "Windows_NT" ]]; then
    packer.exe build -on-error=cleanup -color=false -parallel-builds=$PACKERMAXPROCS -except= packer-cache.json 2>&1 | tr -cs [:print:] [\\n*] | grep --line-buffered --color=none -E "Download progress|Downloading or copying|Found already downloaded|Transferred:|[0-9]*[[:space:]]*items:"
  else
    packer build -on-error=cleanup -color=false -parallel-builds=$PACKERMAXPROCS -except= packer-cache.json 2>&1 | tr -cs [:print:] [\\n*] | grep --line-buffered --color=none -E "Download progress|Downloading or copying|Found already downloaded|Transferred:|[0-9]*[[:space:]]*items:"
  fi

  if [[ $? != 0 ]]; then
    tput setaf 1; tput bold; printf "\n\nDistro disc image download aborted...\n\n"; tput sgr0
  else
    tput setaf 2; tput bold; printf "\n\nDistro disc images have finished downloading...\n\n"; tput sgr0
  fi

}

# Verify all of the ISO locations are still valid.
function verify_url {

  # Grab just the response header and look for the 200 response code to indicate the link is valid.
  ${CURL} --head --silent --location --retry 3 --retry-delay 4 --connect-timeout 60 "$1" | grep --extended-regexp "HTTP/1\.1 [0-9]*|HTTP/2\.0 [0-9]*|HTTP/2 [0-9]*" | tail -1 | grep --silent --extended-regexp "HTTP/1\.1 200 OK|HTTP/2\.0 200 OK|HTTP/2 200"

  # The grep return code tells us whether it found a match in the header or not.
  if [ $? != 0 ]; then

    # Wait a minute, and then try again. Many of the failures are transient network errors.
    sleep 10; ${CURL} --head --silent --location --retry 3 --retry-delay 4 --connect-timeout 60 "$1" |  grep --extended-regexp "HTTP/1\.1 [0-9]*|HTTP/2\.0 [0-9]*|HTTP/2 [0-9]*" | tail -1 | grep --silent --extended-regexp "HTTP/1\.1 200 OK|HTTP/2\.0 200 OK|HTTP/2 200"

    if [ $? != 0 ]; then
      printf "Link Failure:  $1\n"
      return 1
    fi
  fi
}

# Verify all of the ISO locations are valid and then download the ISO and verify the hash.
function verify_sum {

  # Grab just the response header and look for the 200 response code to indicate the link is valid.
  ${CURL} --silent --location --head "$1" | grep --extended-regexp "HTTP/1\.1 200 OK|HTTP/2\.0 200 OK|HTTP/2 200" | tail -1 | grep --silent --extended-regexp "HTTP/1\.1 200 OK|HTTP/2\.0 200 OK|HTTP/2 200"

  # The grep return code tells us whether it found a match in the header or not.
  if [ $? != 0 ]; then
    printf "Link Failure:  $1\n\n"
    exit 1
  fi

  # Grab the ISO and pipe the data through sha256sum, then compare the checksum value.
  SUM=`${CURL} --silent --location "$1" | sha256sum | tr -d '  -'`
  echo $SUM | grep --silent "$2"

  # The grep return code tells us whether we found a checksum match.
  if [ $? != 0 ]; then

    # Wait a minute, and then try again. Many of the failures are transient network errors.
    SUM=`sleep 60; ${CURL} --silent --location "$1" | sha256sum | tr -d '  -'`
    echo $SUM | grep --silent "$2"

    if [ $? != 0 ]; then
      printf "Hash Failure:  $1\n"
      printf "Found       -  $SUM\n"
      printf "Expected    -  $2\n\n"
      exit 1
    fi
  fi

  printf "Validated   :  $1\n"
  return 0
}

# Verify the local ISO files are valid and if necessary download the file.
function verify_local {

  ISOAGENT="Mozilla/5.0 (X11; Linux x86_64; rv:52.0) Gecko/20100101 Firefox/52.0"

  # Make sure the ISO exists, and is the proper size.
  if [ ! -f "${2}" ] || [ "`sha256sum \"${2}\" | awk -F' ' '{print \$1}'`" != "${1}" ]; then
    ${CURL} --location --retry 16 --retry-delay 16 --max-redirs 16 --user-agent "${ISOAGENT}" --output "${2}.part" "${3}"
    sha256sum "${2}.part" | grep --silent "${1}"
    if [ $? != 0 ]; then
      tput setaf 1; tput bold; printf "\n\nLocal ISO file could not be downloaded...\n\n"; tput sgr0
      rm --force "${2}"
    else
      mv --force "${2}.part" "${2}"
    fi
  fi
}

# Validate the templates before building.
function verify_json() {

  unset LD_PRELOAD ; unset LD_LIBRARY_PATH ;

  if [[ $OS == "Windows_NT" ]]; then
    packer.exe validate $1.json
  else
    packer validate $1.json
  fi

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

# Check whether a box has been uploaded to the cloud.
function verify_availability() {

  local RESULT=0

  curltry ${CURL} --head --fail --silent --location --user-agent "${AGENT}" --output /dev/null --write-out "%{http_code}" "https://vagrantcloud.com/$1/boxes/$2/versions/$4/providers/$3.box" | grep --silent "200"

  if [ $? != 0 ]; then
    #printf "Box  -  "; tput setaf 1; printf "${1}/${2} ${3}\n"; tput sgr0
    printf "%sBox  -   %s${1}/${2} ${3}%s \n%s" "`tput sgr0`" "`tput setaf 1`" "`tput sgr0`" "`tput sgr0`"
    let RESULT=1
  else
    #printf "Box  +  "; tput setaf 2; printf "${1}/${2} ${3}\n"; tput sgr0
    printf "%sBox  +   %s${1}/${2} ${3}%s \n%s" "`tput sgr0`" "`tput setaf 2`" "`tput sgr0`" "`tput sgr0`"
  fi

  return $RESULT
}

# Build the boxes and cleanup the packer cache after each run.
function build() {

  verify_logdir
  export INCREMENT=1
  export PACKER_LOG="1"
  unset LD_PRELOAD ; unset LD_LIBRARY_PATH ;

  while [ $INCREMENT != 0 ]; do
    export PACKER_LOG_PATH="$BASE/logs/$1-${INCREMENT}.txt"
    if [ ! -f $PACKER_LOG_PATH ]; then
      let INCREMENT=0
    else
      let INCREMENT=$INCREMENT+1
    fi
  done

  if [[ $OS == "Windows_NT" ]]; then
    packer.exe build -on-error=cleanup -parallel-builds=$PACKERMAXPROCS -except="${EXCEPTIONS}" $1.json
  else
    packer build -on-error=cleanup -parallel-builds=$PACKERMAXPROCS -except="${EXCEPTIONS}" $1.json
  fi

  if [[ $? != 0 ]]; then
    tput setaf 1; tput bold; printf "\n\n$1 images failed to build properly...\n\n"; tput sgr0

    # Auto retry any boxes that failed.
    which jq &> /dev/null
    if [[ $? == 0 ]]; then
      LIST=(`cat $1.json | jq -r " .builders | .[] |  .name " | sort`)
      for ((i = 0; i < ${#LIST[@]}; ++i)); do
        if [ ! -f "$BASE/output/${LIST[$i]}-$VERSION.box" ]; then
          packer build -parallel-builds=$PACKERMAXPROCS -only="${LIST[$i]}" -except="${EXCEPTIONS}" $1.json
        fi
      done
    fi

    for i in 1 2 3; do printf "\a"; sleep 1; done
  fi
}

# Build an individual box.
function box() {

  verify_logdir
  export PACKER_LOG="1"
  export TIMESTAMP=`date +"%Y%m%d.%I%M"`
  unset LD_PRELOAD ; unset LD_LIBRARY_PATH ;

  if [[ $OS == "Windows_NT" ]]; then

      export PACKER_LOG_PATH="$BASE/logs/magma-log-${TIMESTAMP}.txt"
      [[ "$1" =~ ^.*magma.*$ ]] && [[ "$1" =~ ^.*hyperv.*$ ]] && packer.exe build -on-error=cleanup -parallel-builds=$PACKERMAXPROCS -only=$1 magma-hyperv.json
      export PACKER_LOG_PATH="$BASE/logs/generic-log-${TIMESTAMP}.txt"
      [[ "$1" =~ ^.*generic.*$ ]] && [[ "$1" =~ ^.*hyperv.*$ ]] && packer.exe build -on-error=cleanup -parallel-builds=$PACKERMAXPROCS -only=$1 generic-hyperv.json
      export PACKER_LOG_PATH="$BASE/logs/lineage-log-${TIMESTAMP}.txt"
      [[ "$1" =~ ^.*lineage.*$ ]] && [[ "$1" =~ ^.*hyperv.*$ ]] && packer.exe build -on-error=cleanup -parallel-builds=$PACKERMAXPROCS -only=$1 lineage-hyperv.json
      export PACKER_LOG_PATH="$BASE/logs/developer-log-${TIMESTAMP}.txt"
      [[ "$1" =~ ^.*developer.*$ ]] && [[ "$1" =~ ^.*hyperv.*$ ]] && packer.exe build -on-error=cleanup -parallel-builds=$PACKERMAXPROCS -only=$1 developer-hyperv.json

  fi

  if [[ `uname` == "Darwin" ]]; then

      export PACKER_LOG_PATH="$BASE/logs/generic-log-${TIMESTAMP}.txt"
      [[ "$1" =~ ^.*generic.*$ ]] && [[ "$1" =~ ^.*parallels.*$ ]] && packer build -on-error=cleanup -parallel-builds=$PACKERMAXPROCS -only=$1 generic-parallels.json

  fi

  if [[ `uname` == "Linux" ]]; then

      export PACKER_LOG_PATH="$BASE/logs/magma-docker-log-${TIMESTAMP}.txt"
      [[ "$1" =~ ^.*magma.*$ ]] && [[ "$1" =~ ^.*docker.*$ ]] && (docker-login && packer build -on-error=cleanup -parallel-builds=$PACKERMAXPROCS -only=$1 magma-docker.json; docker-logout)
      export PACKER_LOG_PATH="$BASE/logs/magma-libvirt-log-${TIMESTAMP}.txt"
      [[ "$1" =~ ^.*magma.*$ ]] && [[ "$1" =~ ^.*libvirt.*$ ]] && packer build -on-error=cleanup -parallel-builds=$PACKERMAXPROCS -only=$1 magma-libvirt.json

      export PACKER_LOG_PATH="$BASE/logs/generic-docker-log-${TIMESTAMP}.txt"
      [[ "$1" =~ ^.*generic.*$ ]] && [[ "$1" =~ ^.*docker.*$ ]] && (docker-login && packer build -on-error=cleanup -parallel-builds=$PACKERMAXPROCS -only=$1 generic-docker.json; docker-logout)
      export PACKER_LOG_PATH="$BASE/logs/generic-libvirt-x32-log-${TIMESTAMP}.txt"
      [[ "$1" =~ ^.*generic.*$ ]] && [[ "$1" =~ ^.*x32-libvirt.*$ ]] && packer build -on-error=cleanup -parallel-builds=$PACKERMAXPROCS -only=$1 generic-libvirt-x32.json
      export PACKER_LOG_PATH="$BASE/logs/generic-libvirt-log-${TIMESTAMP}.txt"
      [[ "$1" =~ ^.*generic.*$ ]] && [[ "$1" =~ ^.*libvirt.*$ ]] && packer build -on-error=cleanup -parallel-builds=$PACKERMAXPROCS -only=$1 generic-libvirt.json

      export PACKER_LOG_PATH="$BASE/logs/developer-ova-log-${TIMESTAMP}.txt"
      [[ "$1" =~ ^.*developer.*$ ]] && [[ "$1" =~ ^.*ova.*$ ]] && packer build -on-error=cleanup -parallel-builds=$PACKERMAXPROCS -only=$1 developer-ova.json
      export PACKER_LOG_PATH="$BASE/logs/developer-libvirt-log-${TIMESTAMP}.txt"
      [[ "$1" =~ ^.*developer.*$ ]] && [[ "$1" =~ ^.*libvirt.*$ ]] && packer build -on-error=cleanup -parallel-builds=$PACKERMAXPROCS -only=$1 developer-libvirt.json

      export PACKER_LOG_PATH="$BASE/logs/lineage-libvirt-log-${TIMESTAMP}.txt"
      [[ "$1" =~ ^.*lineage.*$ ]] && [[ "$1" =~ ^.*libvirt.*$ ]] && packer build -on-error=cleanup -parallel-builds=$PACKERMAXPROCS -only=$1 lineage-libvirt.json

  fi

  export PACKER_LOG_PATH="$BASE/logs/magma-vmware-log-${TIMESTAMP}.txt"
  [[ "$1" =~ ^.*magma.*$ ]] && [[ "$1" =~ ^.*vmware.*$ ]] && packer build -on-error=cleanup -parallel-builds=$PACKERMAXPROCS -only=$1 magma-vmware.json
  export PACKER_LOG_PATH="$BASE/logs/magma-virtualbox-log-${TIMESTAMP}.txt"
  [[ "$1" =~ ^.*magma.*$ ]] && [[ "$1" =~ ^.*virtualbox.*$ ]] && packer build -on-error=cleanup -parallel-builds=$PACKERMAXPROCS -only=$1 magma-virtualbox.json

  export PACKER_LOG_PATH="$BASE/logs/generic-vmware-log-${TIMESTAMP}.txt"
  [[ "$1" =~ ^.*generic.*$ ]] && [[ "$1" =~ ^.*vmware.*$ ]] && packer build -on-error=cleanup -parallel-builds=$PACKERMAXPROCS -only=$1 generic-vmware.json
  export PACKER_LOG_PATH="$BASE/logs/generic-virtualbox-log-${TIMESTAMP}.txt"
  [[ "$1" =~ ^.*generic.*$ ]] && [[ "$1" =~ ^.*virtualbox.*$ ]] && packer build -on-error=cleanup -parallel-builds=$PACKERMAXPROCS -only=$1 generic-virtualbox.json

  export PACKER_LOG_PATH="$BASE/logs/developer-vmware-log-${TIMESTAMP}.txt"
  [[ "$1" =~ ^.*developer.*$ ]] && [[ "$1" =~ ^.*vmware.*$ ]] && packer build -on-error=cleanup -parallel-builds=$PACKERMAXPROCS -only=$1 developer-vmware.json
  export PACKER_LOG_PATH="$BASE/logs/developer-virtualbox-log-${TIMESTAMP}.txt"
  [[ "$1" =~ ^.*developer.*$ ]] && [[ "$1" =~ ^.*virtualbox.*$ ]] && packer build -on-error=cleanup -parallel-builds=$PACKERMAXPROCS -only=$1 developer-virtualbox.json

  export PACKER_LOG_PATH="$BASE/logs/lineage-vmware-log-${TIMESTAMP}.txt"
  [[ "$1" =~ ^.*lineage.*$ ]] && [[ "$1" =~ ^.*vmware.*$ ]] && packer build -on-error=cleanup -parallel-builds=$PACKERMAXPROCS -only=$1 lineage-vmware.json
  export PACKER_LOG_PATH="$BASE/logs/lineage-virtualbox-log-${TIMESTAMP}.txt"
  [[ "$1" =~ ^.*lineage.*$ ]] && [[ "$1" =~ ^.*virtualbox.*$ ]] && packer build -on-error=cleanup -parallel-builds=$PACKERMAXPROCS -only=$1 lineage-virtualbox.json

  return 0
}

function links() {

  MURLS=(`echo $MEDIAURLS | sed "s/|/ /g"`)

  for ((i = 0; i < ${#MURLS[@]}; ++i)); do
    (verify_url "${MURLS[$i]}") &
    sleep 0.1 &> /dev/null || echo "" &> /dev/null
  done

  for ((i = 0; i < ${#UNIQURLS[@]}; ++i)); do
    (verify_url "${UNIQURLS[$i]}") &
    sleep 0.1 &> /dev/null || echo "" &> /dev/null
  done

  # Wait until the children done working.
  wait

  # Combine the media URLs with the regular box ISO urls.
  let TOTAL=${#UNIQURLS[@]}+${#MURLS[@]}

  # Let the user know all of the links passed.
  printf "\nAll $TOTAL of the install media locations have been checked...\n\n"
}

function sums() {

  # for ((i = 0; i < ${#ISOURLS[@]}; ++i)); do
  #     verify_sum "${ISOURLS[$i]}" "${ISOSUMS[$i]}"
  # done

  export -f verify_sum
  parallel -j 16 --xapply verify_sum {1} {2} ":::" "${ISOURLS[@]}" ":::" "${ISOSUMS[@]}"

  # Let the user know all of the links passed.
  # printf "\nAll ${#ISOURLS[@]} of the install media locations have been validated...\n\n"
}

function validate() {
  verify_json packer-cache
  verify_json magma-docker
  verify_json magma-hyperv
  verify_json magma-vmware
  verify_json magma-libvirt
  verify_json magma-virtualbox
  verify_json generic-docker
  verify_json generic-hyperv
  verify_json generic-vmware
  verify_json generic-libvirt
  verify_json generic-libvirt-x32
  verify_json generic-parallels
  verify_json generic-virtualbox
  verify_json developer-ova
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
        # With OVA boxes we need to parse the box name and convert it to a filename.
        if [[ "${LIST[$i]}" =~ ^.*-ova$ ]]; then
          FILENAME=`echo "${LIST[$i]}" | sed "s/\([a-z]*-[a-z0-9-]*\)-ova/\1-${VERSION}.ova/g"`
          if [ ! -f $BASE/output/"$FILENAME" ]; then
            let MISSING+=1
            printf "Box  -  "; tput setaf 1; printf "${LIST[$i]}\n"; tput sgr0
          else
            printf "Box  +  "; tput setaf 2; printf "${LIST[$i]}\n"; tput sgr0
          fi
        # With Docker boxes we need to look for a tarball and a box file.
        elif [[ "${LIST[$i]}" =~ ^.*-docker$ ]]; then
          if [ ! -f $BASE/output/"${LIST[$i]}-${VERSION}.tar.gz" ] || [ ! -f $BASE/output/"${LIST[$i]}-${VERSION}.box" ]; then
            let MISSING+=1
            printf "Box  -  "; tput setaf 1; printf "${LIST[$i]}\n"; tput sgr0
          else
            printf "Box  +  "; tput setaf 2; printf "${LIST[$i]}\n"; tput sgr0
          fi
        else
          if [ ! -f $BASE/output/"${LIST[$i]}-${VERSION}.box" ]; then
            let MISSING+=1
            printf "Box  -  "; tput setaf 1; printf "${LIST[$i]}\n"; tput sgr0
          else
            printf "Box  +  "; tput setaf 2; printf "${LIST[$i]}\n"; tput sgr0
          fi
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

      PROVIDER="docker"
      if [[ "${ORGANIZATION}" =~ ^(generic|roboxes|lavabit)$ ]]; then
        if [[ "${BOX}" == "centos6" ]] || [[ "${BOX}" == "centos7" ]] || [[ "${BOX}" == "centos8" ]] || \
          [[ "${BOX}" == "rhel6" ]] || [[ "${BOX}" == "rhel7" ]] || [[ "${BOX}" == "rhel8" ]] || \
          [[ "${BOX}" == "oracle7" ]] || [[ "${BOX}" == "oracle8" ]] || \
          [[ "${BOX}" == "magma" ]] || [[ "${BOX}" == "magma-centos" ]] || \
          [[ "${BOX}" == "magma-centos6" ]] || [[ "${BOX}" == "magma-centos7" ]]; then
          ${CURL} --head --silent --location --user-agent "${AGENT}" "https://app.vagrantup.com/${ORGANIZATION}/boxes/${BOX}/versions/${VERSION}/providers/${PROVIDER}.box" | head -1 | grep --silent --extended-regexp "HTTP/1\.1 200 OK|HTTP/2\.0 200 OK|HTTP/2 200|HTTP/1\.1 302 Found|HTTP/2.0 302 Found|HTTP/2 302 Found"

          if [ $? != 0 ]; then
            let MISSING+=1
            printf "Box  -  "; tput setaf 1; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
          else
            let FOUND+=1
            printf "Box  +  "; tput setaf 2; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
          fi
        fi
      fi

      PROVIDER="hyperv"
      ${CURL} --head --silent --location --user-agent "${AGENT}" "https://app.vagrantup.com/${ORGANIZATION}/boxes/${BOX}/versions/${VERSION}/providers/${PROVIDER}.box?access_token=${VAGRANT_CLOUD_TOKEN}" | head -1 | grep --silent --extended-regexp "HTTP/1\.1 200 OK|HTTP/2\.0 200 OK|HTTP/2 200|HTTP/1\.1 302 Found|HTTP/2.0 302 Found|HTTP/2 302 Found"

      if [ $? != 0 ]; then
        let MISSING+=1
        printf "Box  -  "; tput setaf 1; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
      else
        let FOUND+=1
        printf "Box  +  "; tput setaf 2; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
      fi

      PROVIDER="libvirt"
      ${CURL} --head --silent --location --user-agent "${AGENT}" "https://app.vagrantup.com/${ORGANIZATION}/boxes/${BOX}/versions/${VERSION}/providers/${PROVIDER}.box?access_token=${VAGRANT_CLOUD_TOKEN}" | head -1 | grep --silent --extended-regexp "HTTP/1\.1 200 OK|HTTP/2\.0 200 OK|HTTP/2 200|HTTP/1\.1 302 Found|HTTP/2.0 302 Found|HTTP/2 302 Found"

      if [ $? != 0 ]; then
        let MISSING+=1
        printf "Box  -  "; tput setaf 1; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
      else
        let FOUND+=1
        printf "Box  +  "; tput setaf 2; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
      fi

      PROVIDER="parallels"
      if [[ "${ORGANIZATION}" == "generic" ]]; then
        ${CURL} --head --silent --location --user-agent "${AGENT}" "https://app.vagrantup.com/${ORGANIZATION}/boxes/${BOX}/versions/${VERSION}/providers/${PROVIDER}.box?access_token=${VAGRANT_CLOUD_TOKEN}" | head -1 | grep --silent --extended-regexp "HTTP/1\.1 200 OK|HTTP/2\.0 200 OK|HTTP/2 200|HTTP/1\.1 302 Found|HTTP/2.0 302 Found|HTTP/2 302 Found"

        if [ $? != 0 ]; then
          let MISSING+=1
          printf "Box  -  "; tput setaf 1; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
        else
          let FOUND+=1
          printf "Box  +  "; tput setaf 2; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
        fi
      fi

      PROVIDER="virtualbox"
      ${CURL} --head --silent --location --user-agent "${AGENT}" "https://app.vagrantup.com/${ORGANIZATION}/boxes/${BOX}/versions/${VERSION}/providers/${PROVIDER}.box?access_token=${VAGRANT_CLOUD_TOKEN}" | head -1 | grep --silent --extended-regexp "HTTP/1\.1 200 OK|HTTP/2\.0 200 OK|HTTP/2 200|HTTP/1\.1 302 Found|HTTP/2.0 302 Found|HTTP/2 302 Found"

      if [ $? != 0 ]; then
        let MISSING+=1
        printf "Box  -  "; tput setaf 1; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
      else
        let FOUND+=1
        printf "Box  +  "; tput setaf 2; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
      fi

      PROVIDER="vmware_desktop"
      ${CURL} --head --silent --location --user-agent "${AGENT}" "https://app.vagrantup.com/${ORGANIZATION}/boxes/${BOX}/versions/${VERSION}/providers/${PROVIDER}.box?access_token=${VAGRANT_CLOUD_TOKEN}" | head -1 | grep --silent --extended-regexp "HTTP/1\.1 200 OK|HTTP/2\.0 200 OK|HTTP/2 200|HTTP/1\.1 302 Found|HTTP/2.0 302 Found|HTTP/2 302 Found"

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

      PROVIDER="docker"
      if [[ "${ORGANIZATION}" =~ ^(generic|roboxes|lavabit)$ ]]; then
        if [[ "${BOX}" == "centos6" ]] || [[ "${BOX}" == "centos7" ]] || [[ "${BOX}" == "centos8" ]] || \
          [[ "${BOX}" == "rhel6" ]] || [[ "${BOX}" == "rhel7" ]] || [[ "${BOX}" == "rhel8" ]] || \
          [[ "${BOX}" == "oracle7" ]] || [[ "${BOX}" == "oracle8" ]] || \
          [[ "${BOX}" == "magma" ]] || [[ "${BOX}" == "magma-centos" ]] || \
          [[ "${BOX}" == "magma-centos6" ]] || [[ "${BOX}" == "magma-centos7" ]]; then
          curltry ${CURL} --head --fail --silent --location --user-agent "${AGENT}" --output /dev/null --write-out "%{http_code}" "https://app.vagrantup.com/${ORGANIZATION}/boxes/${BOX}/versions/${VERSION}/providers/${PROVIDER}.box" | grep --silent "200"

          if [ $? != 0 ]; then
            let MISSING+=1
            printf "Box  -  "; tput setaf 1; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
          else
            let FOUND+=1
            printf "Box  +  "; tput setaf 2; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
          fi
        fi
      fi

      PROVIDER="hyperv"
      curltry ${CURL} --head --fail --silent --location --user-agent "${AGENT}" --output /dev/null --write-out "%{http_code}" "https://app.vagrantup.com/${ORGANIZATION}/boxes/${BOX}/versions/${VERSION}/providers/${PROVIDER}.box" | grep --silent "200"

      if [ $? != 0 ]; then
        let MISSING+=1
        printf "Box  -  "; tput setaf 1; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
      else
        let FOUND+=1
        printf "Box  +  "; tput setaf 2; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
      fi

      PROVIDER="libvirt"
      curltry ${CURL} --head --fail --silent --location --user-agent "${AGENT}" --output /dev/null --write-out "%{http_code}" "https://app.vagrantup.com/${ORGANIZATION}/boxes/${BOX}/versions/${VERSION}/providers/${PROVIDER}.box" | grep --silent "200"

      if [ $? != 0 ]; then
        let MISSING+=1
        printf "Box  -  "; tput setaf 1; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
      else
        let FOUND+=1
        printf "Box  +  "; tput setaf 2; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
      fi

      PROVIDER="parallels"
      if [[ "${ORGANIZATION}" =~ ^(generic|roboxes)$ ]]; then
        curltry ${CURL} --head --fail --silent --location --user-agent "${AGENT}" --output /dev/null --write-out "%{http_code}" "https://app.vagrantup.com/${ORGANIZATION}/boxes/${BOX}/versions/${VERSION}/providers/${PROVIDER}.box" | grep --silent "200"

        if [ $? != 0 ]; then
          let MISSING+=1
          printf "Box  -  "; tput setaf 1; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
        else
          let FOUND+=1
          printf "Box  +  "; tput setaf 2; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
        fi
      fi

      PROVIDER="virtualbox"
      curltry ${CURL} --head --fail --silent --location --user-agent "${AGENT}" --output /dev/null --write-out "%{http_code}" "https://app.vagrantup.com/${ORGANIZATION}/boxes/${BOX}/versions/${VERSION}/providers/${PROVIDER}.box" | grep --silent "200"

      if [ $? != 0 ]; then
        let MISSING+=1
        printf "Box  -  "; tput setaf 1; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
      else
        let FOUND+=1
        printf "Box  +  "; tput setaf 2; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
      fi

      PROVIDER="vmware_desktop"
      curltry ${CURL} --head --fail --silent --location --user-agent "${AGENT}" --output /dev/null --write-out "%{http_code}" "https://app.vagrantup.com/${ORGANIZATION}/boxes/${BOX}/versions/${VERSION}/providers/${PROVIDER}.box" | grep --silent "200"

      if [ $? != 0 ]; then
        let MISSING+=1
        printf "Box  -  "; tput setaf 1; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
      else
        let FOUND+=1
        printf "Box  +  "; tput setaf 2; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
      fi

      # Limit requests to ~100 per minute to avoid stalls.
      sleep 0.6 &> /dev/null || echo "" &> /dev/null

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

function ppublic() {

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

      PROVIDER="docker"
      if [[ "${ORGANIZATION}" =~ ^(generic|roboxes|lavabit)$ ]]; then
        if [[ "${BOX}" == "centos6" ]] || [[ "${BOX}" == "centos7" ]] || [[ "${BOX}" == "centos8" ]] || \
          [[ "${BOX}" == "rhel6" ]] || [[ "${BOX}" == "rhel7" ]] || [[ "${BOX}" == "rhel8" ]] || \
          [[ "${BOX}" == "oracle7" ]] || [[ "${BOX}" == "oracle8" ]] || \
          [[ "${BOX}" == "magma" ]] || [[ "${BOX}" == "magma-centos" ]] || \
          [[ "${BOX}" == "magma-centos6" ]] || [[ "${BOX}" == "magma-centos7" ]]; then
            O=( "${O[@]}" "${ORGANIZATION}" ); B=( "${B[@]}" "${BOX}" ); P=( "${P[@]}" "${PROVIDER}" ); V=( "${V[@]}" "${VERSION}" );
        fi
      fi

      PROVIDER="hyperv"
      O=( "${O[@]}" "${ORGANIZATION}" ); B=( "${B[@]}" "${BOX}" ); P=( "${P[@]}" "${PROVIDER}" ); V=( "${V[@]}" "${VERSION}" );

      PROVIDER="libvirt"
      O=( "${O[@]}" "${ORGANIZATION}" ); B=( "${B[@]}" "${BOX}" ); P=( "${P[@]}" "${PROVIDER}" ); V=( "${V[@]}" "${VERSION}" );

      PROVIDER="parallels"
      if [[ "${ORGANIZATION}" =~ ^(generic|roboxes)$ ]]; then
        O=( "${O[@]}" "${ORGANIZATION}" ); B=( "${B[@]}" "${BOX}" ); P=( "${P[@]}" "${PROVIDER}" ); V=( "${V[@]}" "${VERSION}" );
      fi

      PROVIDER="virtualbox"
      O=( "${O[@]}" "${ORGANIZATION}" ); B=( "${B[@]}" "${BOX}" ); P=( "${P[@]}" "${PROVIDER}" ); V=( "${V[@]}" "${VERSION}" );

      PROVIDER="vmware_desktop"
      O=( "${O[@]}" "${ORGANIZATION}" ); B=( "${B[@]}" "${BOX}" ); P=( "${P[@]}" "${PROVIDER}" ); V=( "${V[@]}" "${VERSION}" );

    done

    export -f curltry ; export -f verify_availability ; export CURL ;
    # parallel --jobs 16 --keep-order --xapply verify_availability {1} {2} {3} {4} ":::" "${O[@]}" ":::" "${B[@]}" ":::" "${P[@]}" ":::" "${V[@]}"
    parallel --jobs 4 --keep-order --line-buffer --xapply verify_availability {1} {2} {3} {4} '||' let MISSING+=1 ":::" "${O[@]}" ":::" "${B[@]}" ":::" "${P[@]}" ":::" "${V[@]}"
    # Get the totla number of boxes.
    let TOTAL=${#B[@]}
    let FOUND=${TOTAL}-${MISSING}

    # Let the user know how many boxes were missing.
    if [ $MISSING -eq 0 ]; then
      printf "\nAll ${TOTAL} of the boxes are available...\n\n"
    else
      printf "\nOf the ${TOTAL} boxes defined, ${FOUND} are publicly available, while ${MISSING} are unavailable...\n\n"
    fi
}

function grab() {

  URL=`curl --fail --silent --location --user-agent "${AGENT}" "https://app.vagrantup.com/api/v1/box/$1/$2" \
    | jq -r -c "[ .versions[] | .providers[] | select( .name | contains(\"$3\")) | .download_url ][0]" 2>/dev/null`
  if [ "$URL" == "" ]; then
    printf "\nA copy of " ; tput setaf 1 ; printf "$1/$2" ; tput sgr0 ; printf " using the provider " ; tput setaf 1 ; printf "$3" ; tput sgr0 ; printf " couldn't be found.\n\n"
    return 0
  fi

  CHECKSUM=`${CURL} --fail --silent --location --user-agent "${AGENT}" "https://app.vagrantup.com/api/v1/box/$1/$2" \
    | jq -r -c "[ .versions[] | .providers[] | select( .name | contains(\"$3\")) | .checksum ][0]" 2>/dev/null`

  if [ ! -d "$BASE/output/" ]; then
    mkdir "$BASE/output/"
  fi

  ${CURL} --fail --location --user-agent "${AGENT}" --output "$BASE/output/$1-$2-$3-$VERSION.box" "$URL"
  if [ "$?" == 0 ]; then
    ( cd output ; printf "$CHECKSUM\t$1-$2-$3-$VERSION.box" | sha256sum --check --status )
    if [ "$?" != 0 ]; then
      rm --force "$BASE/output/$1-$2-$3-$VERSION.box"
      printf "\nThe hash check for " ; tput setaf 1 ; printf "$1/$2" ; tput sgr0 ; printf " with the provider " ; tput setaf 1 ; printf "$3" ; tput sgr0 ; printf " failed.\n\n"
      return 0
    fi
    ( cd output ; sha256sum "$1-$2-$3-$VERSION.box" | sed -E "s/(.{64})  (.*)/\1\t\2/g" ) > "$BASE/output/$1-$2-$3-$VERSION.box.sha256"
  else
    rm --force "$BASE/output/$1-$2-$3-$VERSION.box"
    printf "\nDownloading " ; tput setaf 1 ; printf "$1/$2" ; tput sgr0 ; printf " with the provider " ; tput setaf 1 ; printf "$3" ; tput sgr0 ; printf " failed.\n\n"
    return 0
  fi

}

function localized() {

  MSUMS=(`echo $MEDIASUMS | sed "s/|/ /g"`)
  MURLS=(`echo $MEDIAURLS | sed "s/|/ /g"`)
  MFILES=(`echo $MEDIAFILES | sed "s/|/ /g"`)

  # RHEL 6
  verify_local "${MSUMS[0]}" "${MFILES[0]}" "${MURLS[0]}"
  # RHEL 7
  verify_local "${MSUMS[1]}" "${MFILES[1]}" "${MURLS[1]}"
  # RHEL 8
  verify_local "${MSUMS[2]}" "${MFILES[2]}" "${MURLS[2]}"

  # Former Logic
  # verify_local 1e15f9202d2cdd4b2bdf9d6503a8543347f0cb8cc06ba9a0dfd2df4fdef5c727 res/media/rhel-server-6.10-x86_64-dvd.iso https://archive.org/download/rhel-server-6.10-x86_64-dvd/rhel-server-6.10-x86_64-dvd.iso
  # verify_local 60a0be5aeed1f08f2bb7599a578c89ec134b4016cd62a8604b29f15d543a469c res/media/rhel-server-7.6-x86_64-dvd.iso https://archive.org/download/rhel-server-7.6-x86_64-dvd/rhel-server-7.6-x86_64-dvd.iso
  # verify_local 005d4f88fff6d63b0fc01a10822380ef52570edd8834321de7be63002cc6cc43 res/media/rhel-8.0-beta-1-x86_64-dvd.iso https://archive.org/download/rhel-8.0-x86_64-dvd/rhel-8.0-x86_64-dvd.iso

}

function cleanup() {
  rm -rf $BASE/packer_cache/ $BASE/output/ $BASE/logs/
}

function docker-login() {

  # If jq is installed, we can use it to determine whether a login is required. Otherwise we rely on the more primitive login logic.
  if [ -f /usr/bin/jq ] || [ -f /usr/local/bin/jq ]; then
    if [[ `jq "[ .auths.\"quay.io\" ]" ~/.docker/config.json | jq " .[] | length"` == 0 ]]; then
      docker login -u "$QUAY_USER" -p "$QUAY_PASSWORD" quay.io
      if [[ $? != 0 ]]; then
        tput setaf 1; tput bold; printf "\n\nThe quay.io login credentials failed.\n\n"; tput sgr0
        read -t 30 -r -p "Would you like to conitnue? [Y/n]: " RESPONSE
        RESPONSE=${RESPONSE,,}
        if [[ ! $RESPONSE =~ ^(yes|y| ) ]] && [[ ! -z $RESPONSE ]]; then
          exit 1
        fi
      fi
    fi
    if [[ `jq "[ .auths.\"docker.io\" ]" ~/.docker/config.json | jq " .[] | length"` == 0 ]] || [[ `jq "[ .auths.\"https://index.docker.io/v1/\" ]" ~/.docker/config.json | jq " .[] | length"` == 0 ]]; then
      docker login -u "$DOCKER_USER" -p "$DOCKER_PASSWORD" docker.io
      if [[ $? != 0 ]]; then
        tput setaf 1; tput bold; printf "\n\nThe docker.io login credentials failed.\n\n"; tput sgr0
        read -t 30 -r -p "Would you like to conitnue? [Y/n]: " RESPONSE
        RESPONSE=${RESPONSE,,}
        if [[ ! $RESPONSE =~ ^(yes|y| ) ]] && [[ ! -z $RESPONSE ]]; then
          exit 1
        fi
      fi
    fi
  else
    RUNNING=`docker info 2>&1 | grep --count --extended-regexp "^Username:"`

    if [ $RUNNING == 0 ]; then

      docker login -u "$QUAY_USER" -p "$QUAY_PASSWORD" quay.io
      if [[ $? != 0 ]]; then
        tput setaf 1; tput bold; printf "\n\nThe quay.io login credentials failed.\n\n"; tput sgr0
        read -t 30 -r -p "Would you like to conitnue? [Y/n]: " RESPONSE
        RESPONSE=${RESPONSE,,}
        if [[ ! $RESPONSE =~ ^(yes|y| ) ]] && [[ ! -z $RESPONSE ]]; then
          exit 1
        fi
      fi

      docker login -u "$DOCKER_USER" -p "$DOCKER_PASSWORD" docker.io
      if [[ $? != 0 ]]; then
        tput setaf 1; tput bold; printf "\n\nThe docker.io login credentials failed.\n\n"; tput sgr0
        read -t 30 -r -p "Would you like to conitnue? [Y/n]: " RESPONSE
        RESPONSE=${RESPONSE,,}
        if [[ ! $RESPONSE =~ ^(yes|y| ) ]] && [[ ! -z $RESPONSE ]]; then
          exit 1
        fi
      fi
    else
      tput setaf 3; tput bold; printf "\nSkipping registry login because the daemon is already authenticated.\n\n"; tput sgr0
    fi

  fi

}

function docker-logout() {
  RUNNING=`ps -ef | grep --invert grep | grep --count --extended-regexp "packer build.*generic-docker.json|packer build.*magma-docker.json"`

  if [ $RUNNING == 0 ]; then
    docker logout quay.io && docker logout docker.io && docker logout https://index.docker.io/v1/
    if [[ $? != 0 ]]; then
      tput setaf 1; tput bold; printf "\n\nThe registry logout command failed.\n\n"; tput sgr0
      exit 1
    fi
  else
    tput setaf 3; tput bold; printf "\nSkipping registry logout because builds are still running.\n\n"; tput sgr0
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
    build generic-libvirt-x32
    build generic-virtualbox

    docker-login ; build generic-docker; docker-logout
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
    build developer-ova
    build developer-vmware
    build developer-libvirt
    build developer-virtualbox
  fi
}

function ova() {
  verify_json developer-ova

  build developer-ova
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

  unset LD_PRELOAD ; unset LD_LIBRARY_PATH ;

  if [[ $OS == "Windows_NT" ]]; then

    LIST=($BOXES)

    verify_json generic-hyperv
    verify_json magma-hyperv
    verify_json developer-hyperv
    verify_json lineage-hyperv

    # Build the generic boxes first.
    for ((i = 0; i < ${#LIST[@]}; ++i)); do
      if [[ "${LIST[$i]}" =~ ^generic-[a-z]*[0-9]*-hyperv$ ]]; then
        packer build -parallel-builds=$PACKERMAXPROCS -except="${EXCEPTIONS}" -only="${LIST[$i]}" generic-hyperv.json
      fi
    done

    # Build the magma boxes second.
    for ((i = 0; i < ${#LIST[@]}; ++i)); do
      if [[ "${LIST[$i]}" =~ ^magma-hyperv$ ]]; then
        packer build -parallel-builds=$PACKERMAXPROCS -except="${EXCEPTIONS}" -only="${LIST[$i]}" magma-hyperv.json
      fi
    done
    for ((i = 0; i < ${#LIST[@]}; ++i)); do
      if [[ "${LIST[$i]}" =~ ^magma-[a-z]*[0-9]*-hyperv$ ]] && [[ "${LIST[$i]}" != ^magma-developer-hyperv$ ]]; then
        packer build -parallel-builds=$PACKERMAXPROCS -except="${EXCEPTIONS}" -only="${LIST[$i]}" magma-hyperv.json
      fi
    done
    for ((i = 0; i < ${#LIST[@]}; ++i)); do
      if [[ "${LIST[$i]}" =~ ^magma-developer-hyperv$ ]]; then
        packer build -parallel-builds=$PACKERMAXPROCS -except="${EXCEPTIONS}" -only="${LIST[$i]}" developer-hyperv.json
      fi
    done

    # Build the Lineage boxes fourth.
    for ((i = 0; i < ${#LIST[@]}; ++i)); do
      if [[ "${LIST[$i]}" =~ ^(lineage|lineageos)-hyperv$ ]]; then
        packer build -parallel-builds=$PACKERMAXPROCS -except="${EXCEPTIONS}" -only="${LIST[$i]}" lineage-hyperv.json
      fi
    done
    for ((i = 0; i < ${#LIST[@]}; ++i)); do
      if [[ "${LIST[$i]}" =~ ^(lineage|lineageos)-[a-z]*[0-9]*-hyperv$ ]]; then
        packer build -parallel-builds=$PACKERMAXPROCS -except="${EXCEPTIONS}" -only="${LIST[$i]}" lineage-hyperv.json
      fi
    done

  else
    tput setaf 1; tput bold; printf "\n\nThe HyperV roboxes require a Windows host...\n\n"; tput sgr0
  fi
}

function libvirt() {
  verify_json generic-libvirt
  verify_json generic-libvirt-x32
  verify_json magma-libvirt
  verify_json developer-libvirt
  verify_json lineage-libvirt

  build generic-libvirt
  build generic-libvirt-x32
  build magma-libvirt
  build developer-libvirt
  build lineage-libvirt
}

function parallels() {

  unset LD_PRELOAD ; unset LD_LIBRARY_PATH ;

  if [[ `uname` == "Darwin" ]]; then

    # Ideally, we shouldn't need this. However the ancient Macbook Air
    # used to make the Parallels boxes doesn't have the resources to
    # load the full template at once. As a workaround, the logic below
    # makes packer build the boxes, one at a time. This function also
    # removes the box file (but not the checksum) to avoid running out
    # of disk space.

    LIST=($BOXES)

    # verify_json generic-parallels

    # Keep the system awake so it can finish building the boxes.
    if [ -f /usr/bin/caffeinate ]; then
      /usr/bin/caffeinate -w $$ &
    fi

    for ((i = 0; i < ${#LIST[@]}; ++i)); do
      # Ensure there is enough disk space.
      if [[ `df -m . | tail -1 |  awk -F' ' '{print $4}'` -lt 8192 ]]; then
        tput setaf 1; tput bold; printf "\n\nSkipping ${LIST[$i]} because the system is low on disk space.\n\n"; tput sgr0
      elif [[ "${LIST[$i]}" =~ ^(generic|magma)-[a-z]*[0-9]*-parallels$ ]]; then
        # Build the box. If the first attempt fails, try building the box a second time.
        if [ ! -f "$BASE/output/${LIST[$i]}-$VERSION.box" ]; then
          packer build -parallel-builds=$PACKERMAXPROCS -except="${EXCEPTIONS}" -only="${LIST[$i]}" generic-parallels.json \
            || (packer build -parallel-builds=$PACKERMAXPROCS -except="${EXCEPTIONS}" -only="${LIST[$i]}" generic-parallels.json)
        fi
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
  start

  links
  validate

  builder

  for i in 1 2 3; do printf "\a"; sleep 1; done
}

# The stage functions.
if [[ $1 == "start" ]]; then start
elif [[ $1 == "links" ]]; then links
elif [[ $1 == "cache" ]]; then cache
elif [[ $1 == "validate" ]]; then validate
elif [[ $1 == "build" ]]; then builder
elif [[ $1 == "cleanup" ]]; then cleanup

# The type functions.
elif [[ $1 == "ova" ]]; then vmware
elif [[ $1 == "vmware" ]]; then vmware
elif [[ $1 == "hyperv" ]]; then hyperv
elif [[ $1 == "libvirt" ]]; then libvirt
elif [[ $1 == "parallels" ]]; then parallels
elif [[ $1 == "virtualbox" ]]; then virtualbox

# Docker is a command, so to avoid name space isues, we use an inline function.
elif [[ $1 == "docker" ]]; then verify_json generic-docker ; verify_json magma-docker ; docker-login ; build generic-docker ; build magma-docker ; docker-logout

# The helper functions.
elif [[ $1 == "isos" ]]; then isos
elif [[ $1 == "sums" ]]; then sums
elif [[ $1 == "local" ]]; then localized
elif [[ $1 == "missing" ]]; then missing
elif [[ $1 == "public" ]]; then public
elif [[ $1 == "ppublic" ]]; then ppublic
elif [[ $1 == "available" ]]; then available

# Grab and update files automatically.
elif [[ $1 == "iso" ]]; then iso $2
elif [[ $1 == "grab" ]]; then grab $2 $3 $4

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
elif [[ $1 == "generic-libvirt-x32" || $1 == "generic-libvirt-x32.json" ]]; then build generic-libvirt-x32
elif [[ $1 == "generic-parallels" || $1 == "generic-parallels.json" ]]; then build generic-parallels
elif [[ $1 == "generic-virtualbox" || $1 == "generic-virtualbox.json" ]]; then build generic-virtualbox
elif [[ $1 == "generic-docker" || $1 == "generic-docker.json" ]]; then verify_json generic-docker ; docker-login ; build generic-docker ; docker-logout

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
  echo $"  `basename $0` {ova|vmware|hyperv|libvirt|docker|parallels|virtualbox} or"
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
