#!/bin/bash

# Name: robox.sh
# Author: Ladar Levison
#
# Description: Used to build various virtual machines using packer.

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
# Overrides the repo version string with a default value.
# [ ! -n "\$VERSION" ] && VERSION="1.0.0"

# Set the following to override default values.
# [ ! -n "\$GOMAXPROCS" ] && export GOMAXPROCS="2"

# [ ! -n "\$PACKER_ON_ERROR" ] && export PACKER_ON_ERROR="cleanup"
# [ ! -n "\$PACKER_MAX_PROCS" ] && export PACKER_MAX_PROCS="2"
# [ ! -n "\$PACKER_CACHE_DIR" ] && export PACKER_CACHE_DIR="./packer_cache/"
#
# [ ! -n "\$QUAY_USER" ] && export QUAY_USER="LOGIN"
# [ ! -n "\$QUAY_PASSWORD" ] && export QUAY_PASSWORD="PASSWORD"
# [ ! -n "\$DOCKER_USER" ] && export DOCKER_USER="LOGIN"
# [ ! -n "\$DOCKER_PASSWORD" ] && export DOCKER_PASSWORD="PASSWORD"
# [ ! -n "\$VAGRANT_CLOUD_TOKEN" ] && export VAGRANT_CLOUD_TOKEN="TOKEN"

# [ ! -n "\$VMWARE_WORKSTATION" ] && export VMWARE_WORKSTATION="SERIAL"

EOF
tput setaf 1; printf "\n\nCredentials file was missing. Stub file created.\n\n\n"; tput sgr0
sleep 5
fi

# Import the credentials.
source $BASE/.credentialsrc

# Version Information
[ ! -n "$VERSION" ] && export VERSION="4.0.0"
export AGENT="Vagrant/2.2.19 (+https://www.vagrantup.com; ruby2.7.4)"

# Limit the number of cpus packer will use and control how errors are handled.
[ ! -n "$GOMAXPROCS" ] && export GOMAXPROCS="2"
[ ! -n "$PACKER_ON_ERROR" ] && export PACKER_ON_ERROR="cleanup"
[ ! -n "$PACKER_MAX_PROCS" ] && export PACKER_MAX_PROCS="1"
[ ! -n "$PACKER_CACHE_DIR" ] && export PACKER_CACHE_DIR="$BASE/packer_cache/"

# The list of packer config files.
FILES="packer-cache.json "\
"magma-docker.json magma-hyperv.json magma-vmware.json magma-libvirt.json magma-virtualbox.json "\
"generic-docker.json generic-hyperv.json generic-vmware.json generic-libvirt.json generic-libvirt-x32.json generic-parallels.json generic-virtualbox.json generic-virtualbox-x32.json "\
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
DYNAMICURLS="https://cdimage.ubuntu.com/ubuntu-server/daily/current/disco-server-amd64.iso|"\
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
MAGMA_TAGS=`grep -E '"name":' $FILES | awk -F'"' '{print $4}' | grep "magma" | grep -v "magma-developer-ova" | sed "s/magma-/lavabit\/magma-/g" | sed "s/alpine36/alpine/g" | sed "s/freebsd11/freebsd/g" | sed "s/openbsd6/openbsd/g" | sed "s/\(-hyperv\|-vmware\|-libvirt\|-parallels\|-virtualbox\|-docker\)\$//g" | sort -u --field-separator=-`
MAGMA_SPECIAL_TAGS="lavabit/magma lavabit/magma-centos lavabit/magma-ubuntu"
ROBOX_TAGS=`grep -E '"name":' $FILES | awk -F'"' '{print $4}' | grep "generic" | sed "s/generic-/roboxes\//g" | sed "s/roboxes\(.*\)-x32/roboxes-x32\1/g" | sed "s/\(-hyperv\|-vmware\|-libvirt\|-parallels\|-virtualbox\|-docker\)\$//g" | grep -v "roboxes-x32" |sort -u --field-separator=-`
ROBOX_X32_TAGS=`grep -E '"name":' $FILES | awk -F'"' '{print $4}' | grep "generic" | sed "s/generic-/roboxes\//g" | sed "s/roboxes\(.*\)-x32/roboxes-x32\1/g" | sed "s/\(-hyperv\|-vmware\|-libvirt\|-parallels\|-virtualbox\|-docker\)\$//g" | grep "roboxes-x32" |sort -u --field-separator=-`
GENERIC_TAGS=`grep -E '"name":' $FILES | awk -F'"' '{print $4}' | grep "generic" | sed "s/generic-/generic\//g" | sed "s/generic\(.*\)-x32/generic-x32\1/g" | sed "s/\(-hyperv\|-vmware\|-libvirt\|-parallels\|-virtualbox\|-docker\)//g" | grep -v "generic-x32" | sort -u --field-separator=-`
GENERIC_X32_TAGS=`grep -E '"name":' $FILES | awk -F'"' '{print $4}' | grep "generic" | sed "s/generic-/generic\//g" | sed "s/generic\(.*\)-x32/generic-x32\1/g" | sed "s/\(-hyperv\|-vmware\|-libvirt\|-parallels\|-virtualbox\|-docker\)//g" | grep "generic-x32" | sort -u --field-separator=-`
LINEAGE_TAGS=`grep -E '"name":' $FILES | awk -F'"' '{print $4}' | grep "lineage" | sed "s/lineage-/lineage\/lineage-/g" | sed "s/\(-hyperv\|-vmware\|-libvirt\|-parallels\|-virtualbox\|-docker\)\$//g" |  sort -u --field-separator=-`
LINEAGEOS_TAGS=`grep -E '"name":' $FILES | awk -F'"' '{print $4}' | grep "lineage" | sed "s/lineage-/lineageos\/lineage-/g" | sed "s/\(-hyperv\|-vmware\|-libvirt\|-parallels\|-virtualbox\|-docker\)\$//g" |  sort -u --field-separator=-`
MAGMA_TAGS=`echo $MAGMA_SPECIAL_TAGS $MAGMA_TAGS | sed 's/ /\n/g' | sort -u --field-separator=-`
TAGS="$GENERIC_TAGS $GENERIC_X32_TAGS $ROBOX_TAGS $ROBOX_X32_TAGS $MAGMA_TAGS $LINEAGE_TAGS $LINEAGEOS_TAGS"

# These boxes aren't publicly available yet, so we filter them out of available test.
FILTERED_TAGS="lavabit/magma-alpine lavabit/magma-arch lavabit/magma-freebsd lavabit/magma-gentoo lavabit/magma-openbsd"

# A list of configs to skip during complete build operations.
export EXCEPTIONS=""


# Some of the rpositories we use. This will warn us of if they are removed/archived.

# Ubuntu 16.04
REPOS+=( "https://mirrors.edge.kernel.org/ubuntu/dists/xenial/InRelease" )

# Ubuntu 18.04
REPOS+=( "https://mirrors.edge.kernel.org/ubuntu/dists/bionic/InRelease" )

# Ubuntu 20.04
REPOS+=( "https://mirrors.edge.kernel.org/ubuntu/dists/focal/InRelease" )

# Ubuntu 21.04
REPOS+=( "https://mirrors.edge.kernel.org/ubuntu/dists/hirsute/InRelease" )

# Ubuntu 21.10
REPOS+=( "https://mirrors.edge.kernel.org/ubuntu/dists/impish/InRelease" )

# Ubuntu 22.04
REPOS+=( "https://mirrors.edge.kernel.org/ubuntu/dists/jammy/InRelease" )

# Ubuntu 22.10
REPOS+=( "https://mirrors.edge.kernel.org/ubuntu/dists/kinetic/InRelease" )

# Fedora 27
REPOS+=( "https://archives.fedoraproject.org/pub/archive/fedora/linux/releases/27/Everything/x86_64/os/repodata/repomd.xml" )

# Fedora 28
REPOS+=( "https://archives.fedoraproject.org/pub/archive/fedora/linux/releases/28/Everything/x86_64/os/repodata/repomd.xml" )

# Fedora 29
REPOS+=( "https://archives.fedoraproject.org/pub/archive/fedora/linux/releases/29/Everything/x86_64/os/repodata/repomd.xml" )

# Fedora 30
REPOS+=( "https://archives.fedoraproject.org/pub/archive/fedora/linux/releases/30/Everything/x86_64/os/repodata/repomd.xml" )

# Fedora 31
REPOS+=( "https://archives.fedoraproject.org/pub/archive/fedora/linux/releases/31/Everything/x86_64/os/repodata/repomd.xml" )

# Fedora 32
REPOS+=( "https://archives.fedoraproject.org/pub/archive/fedora/linux/releases/32/Everything/x86_64/os/repodata/repomd.xml" )

# Fedora 33
REPOS+=( "https://archives.fedoraproject.org/pub/archive/fedora/linux/releases/33/Everything/x86_64/os/repodata/repomd.xml" )

# Fedora 34
REPOS+=( "https://dl.fedoraproject.org/pub/fedora/linux/releases/34/Server/x86_64/os/repodata/repomd.xml" )

# Fedora 35
REPOS+=( "https://dl.fedoraproject.org/pub/fedora/linux/releases/35/Server/x86_64/os/repodata/repomd.xml" )

# Fedora 36
REPOS+=( "https://dl.fedoraproject.org/pub/fedora/linux/releases/36/Server/x86_64/os/repodata/repomd.xml" )

# CentOS 8 Stream
REPOS+=( "https://mirrors.edge.kernel.org/centos/8-stream/BaseOS/x86_64/os/repodata/repomd.xml" )

# CentOS 9 Stream
REPOS+=( "https://dfw.mirror.rackspace.com/centos-stream/9-stream/BaseOS/x86_64/os/repodata/repomd.xml" )

# FreeBSD 12
REPOS+=( "http://pkg.freebsd.org/FreeBSD:12:amd64/latest/packagesite.txz" )

# FreeBSD 13
REPOS+=( "http://pkg.freebsd.org/FreeBSD:13:amd64/latest/packagesite.txz" )

# FreeBSD 14
REPOS+=( "http://pkg.freebsd.org/FreeBSD:14:amd64/latest/packagesite.txz" )

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
    if [[ $RESULT == 0 ]] || [[ `echo "$OUTPUT" | grep --count --extended-regexp --max-count=1 "^404$|^HTTP/1.1 404|^HTTP/2 404"` == 1 ]]; then
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

  # Confirm the VMware modules loaded.
  if [ -f /usr/bin/vmware-modconfig ]; then
    MODS=`sudo /etc/init.d/vmware status | grep --color=none --extended-regexp "Module vmmon loaded|Module vmnet loaded" | wc -l`
    if [ "$MODS" != "2" ]; then
       printf "Compiling the VMWare kernel modules.\n";
      sudo vmware-modconfig --console --install-all &> /dev/null
      if [ $? != 0 ]; then
        tput setaf 1; tput bold; printf "\n\nThe vmware kernel modules failed to load properly...\n\n"; tput sgr0
        for i in 1 2 3; do printf "\a"; sleep 1; done
        exit 1
      fi
    fi
  fi

  if [ -f /etc/init.d/vmware ]; then sudo /etc/init.d/vmware start ; fi
  if [ -f /etc/init.d/vmware-USBArbitrator ]; then sudo /etc/init.d/vmware-USBArbitrator start ; fi
  if [ -f /etc/init.d/vmware-workstation-server ]; then sudo /etc/init.d/vmware-workstation-server start ; fi

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

  [ ! -n "$JOBS" ] && export JOBS="16"

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
  # URL="https://cdimage.ubuntu.com/ubuntu-server/daily/current/disco-server-amd64.iso"
  # N=( "${N[@]}" "Disco" ); U=( "${U[@]}" "$URL" )

  # Debian Buster
  # URL="https://cdimage.debian.org/cdimage/weekly-builds/amd64/iso-cd/debian-testing-amd64-netinst.iso"
  # N=( "${N[@]}" "Buster" ); U=( "${U[@]}" "$URL" )

  export -f print_iso
  parallel --jobs $JOBS --xapply print_iso {1} {2} ::: "${N[@]}" ::: "${U[@]}"

}

function iso() {

  if [ "$1" == "gentoo" ]; then

    # Find the existing Gentoo URL and hash values.
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

  elif [ "$1" == "centos8s" ]; then
    
    # Find the existing CentOS 8 stream URL and hash values.
    ISO_URL=`cat "$BASE/packer-cache.json" | jq -r -c ".builders[] | select( .name | contains(\"centos8s\")) | .iso_url" 2>/dev/null`
    ISO_CHECKSUM=`cat "$BASE/packer-cache.json" | jq  -r -c ".builders[] | select( .name | contains(\"centos8s\")) | .iso_checksum" 2>/dev/null`

    # Find the CentOS 8 stream URL.
    URL="https://mirrors.edge.kernel.org/centos/8-stream/isos/x86_64/"
    ISO=`${CURL} --fail --silent "${URL}" | grep --invert-match sha256 | grep --extended-regexp --only-matching --max-count=1 "CentOS\-Stream\-8\-x86\_64\-[0-9]{8}\-boot\.iso" | uniq`
    if [ $? != 0 ] || [ "$ISO" == "" ]; then
      tput setaf 1; printf "\nThe CentOS 8 stream ISO update failed.\n\n"; tput sgr0
      return 1
    fi

    # Calculate the new URL.
    URL="${URL}${ISO}"

    # Download the ISO file and calculate the new hash value.
    set -o pipefail
    SHA=`${CURL} --fail --speed-limit 0 --speed-time 10 --silent --location "${URL}" | sha256sum | awk -F' ' '{print $1}'`
    if [ $? != 0 ] || [ "$SHA" == "" ]; then
        tput setaf 1; printf "\nThe CentOS 8 stream ISO update failed.\n\n"; tput sgr0
        return 1
    fi
    set +o pipefail

    # Escape the URL strings.
    URL=`echo $URL | sed "s/\//\\\\\\\\\//g"`
    ISO_URL=`echo $ISO_URL | sed "s/\//\\\\\\\\\//g"`

    # Replace the existing ISO and hash values with the update values.
    sed --in-place "s/$ISO_URL/$URL/g" $FILES
    sed --in-place "s/$ISO_CHECKSUM/sha256:$SHA/g" $FILES
    
  elif [ "$1" == "centos9s" ]; then

    # Find the existing CentOS 9 stream URL and hash values.
    ISO_URL=`cat "$BASE/packer-cache.json" | jq -r -c ".builders[] | select( .name | contains(\"centos9s\")) | .iso_url" 2>/dev/null`
    ISO_CHECKSUM=`cat "$BASE/packer-cache.json" | jq  -r -c ".builders[] | select( .name | contains(\"centos9s\")) | .iso_checksum" 2>/dev/null`

    # Find the CentOS 9 stream URL.
    URL="https://dfw.mirror.rackspace.com/centos-stream/9-stream/BaseOS/x86_64/iso/"
    ISO=`${CURL} --fail --silent "${URL}" | grep --invert-match sha256 | grep --extended-regexp --only-matching --max-count=1 "CentOS\-Stream\-9\-[0-9]{8}\.[0-9]\-x86\_64\-boot\.iso" | uniq`
    if [ $? != 0 ] || [ "$ISO" == "" ]; then
      tput setaf 1; printf "\nThe CentOS 9 stream ISO update failed.\n\n"; tput sgr0
      return 1
    fi

    # Calculate the new URL.
    URL="${URL}${ISO}"

    # Download the ISO file and calculate the new hash value.
    set -o pipefail
    SHA=`${CURL} --fail --speed-limit 0 --speed-time 10 --silent --location "${URL}" | sha256sum | awk -F' ' '{print $1}'`
    if [ $? != 0 ] || [ "$SHA" == "" ]; then
        tput setaf 1; printf "\nThe CentOS 9 stream ISO update failed.\n\n"; tput sgr0
        return 1
    fi
    set +o pipefail

    # Escape the URL strings.
    URL=`echo $URL | sed "s/\//\\\\\\\\\//g"`
    ISO_URL=`echo $ISO_URL | sed "s/\//\\\\\\\\\//g"`

    # Replace the existing ISO and hash values with the update values.
    sed --in-place "s/$ISO_URL/$URL/g" $FILES
    sed --in-place "s/$ISO_CHECKSUM/sha256:$SHA/g" $FILES
    
  elif [ "$1" == "hardened" ] || [ "$1" == "hardenedbsd" ]; then

    # Find the existing HardenedBSD URL and hash values.
    ISO_URL=`cat "$BASE/packer-cache.json" | jq -r -c ".builders[] | select( .name | contains(\"hardenedbsd13\")) | .iso_url" 2>/dev/null`
    ISO_CHECKSUM=`cat "$BASE/packer-cache.json" | jq  -r -c ".builders[] | select( .name | contains(\"hardenedbsd13\")) | .iso_checksum" 2>/dev/null`

    # Find the HardenedBSD URL.
    URL="https://ci-01.nyi.hardenedbsd.org/pub/hardenedbsd/13-stable/amd64/amd64/"
    BUILD=`${CURL} --fail --silent "${URL}" | grep --extended-regexp --only-matching "\"build\-[0-9]{3}/\"" | grep --extended-regexp --only-matching "build\-[0-9]{3}" | sort -r | uniq | head -1`
    if [ $? != 0 ] || [ "$BUILD" == "" ]; then
      tput setaf 1; printf "\nThe HardenedBSD ISO update failed.\n\n"; tput sgr0
      return 1
    fi

    # Calculate the new URL.
    URL="https://ci-01.nyi.hardenedbsd.org/pub/hardenedbsd/13-stable/amd64/amd64/${BUILD}/disc1.iso"

    # Download the ISO file and calculate the new hash value.
    set -o pipefail
    SHA=`${CURL} --fail --speed-limit 0 --speed-time 10 --silent --location "${URL}" | sha256sum | awk -F' ' '{print $1}'`
    if [ $? != 0 ] || [ "$SHA" == "" ]; then
        tput setaf 1; printf "\nThe HardenedBSD ISO update failed.\n\n"; tput sgr0
        return 1
    fi
    set +o pipefail

    # Escape the URL strings.
    URL=`echo $URL | sed "s/\//\\\\\\\\\//g"`
    ISO_URL=`echo $ISO_URL | sed "s/\//\\\\\\\\\//g"`

    # Replace the existing ISO and hash values with the update values.
    sed --in-place "s/$ISO_URL/$URL/g" $FILES
    sed --in-place "s/$ISO_CHECKSUM/sha256:$SHA/g" $FILES
  elif [ "$1" == "stream" ] || [ "$1" == "streams" ]; then
    iso centos8s
    iso centos9s
  elif [ "$1" == "all" ]; then
    iso arch
    iso centos8s
    iso centos9s
    iso gentoo
    iso hardenedbsd
  fi

}

function cache {

  unset PACKER_LOG ; unset LD_PRELOAD ; unset LD_LIBRARY_PATH ;

  if [[ $OS == "Windows_NT" ]]; then
    packer.exe build -on-error=cleanup -color=false -parallel-builds=$PACKER_MAX_PROCS -except= packer-cache.json 2>&1 | tr -cs [:print:] [\\n*] | grep --line-buffered --color=none -E "Download progress|Downloading or copying|Found already downloaded|Transferred:|[0-9]*[[:space:]]*items:"
  else
    packer build -on-error=cleanup -color=false -parallel-builds=$PACKER_MAX_PROCS -except= packer-cache.json 2>&1 | tr -cs [:print:] [\\n*] | grep --line-buffered --color=none -E "Download progress|Downloading or copying|Found already downloaded|Transferred:|[0-9]*[[:space:]]*items:"
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

  RESULT=0
  unset LD_PRELOAD ; unset LD_LIBRARY_PATH ;

  if [[ $OS == "Windows_NT" ]]; then
    PACKER="packer.exe"
  else
    PACKER="packer"
  fi
  
  ${PACKER} validate $1.json &>/dev/null || \
  { tput setaf 1 ; tput bold ; printf "The $1.json file failed to validate.\n" ; tput sgr0 ; exit 1 ; }

}

# Make sure the logging directory is available. If it isn't, then create it.
function verify_logdir {

  if [ ! -d "$BASE/logs/" ]; then
    mkdir -p "$BASE/logs/" || mkdir "$BASE/logs"
  fi
}

# Check whether a box has been uploaded to the cloud.
function verify_availability() {

  local RESULT=0

  if [ ! -z ${CURLOPTS+x} ]; then export CURL="${CURL} $(eval echo $CURLOPTS)" ; fi

  curltry ${CURL} --head --fail --silent --location --user-agent "${AGENT}" --output /dev/null --write-out "%{http_code}" "https://vagrantcloud.com/$1/boxes/$2/versions/$4/providers/$3.box" | grep --silent "200"

  if [ $? != 0 ]; then
    printf "%sBox  -   %s${1}/${2} ${3}%s \n%s" "`tput sgr0`" "`tput setaf 1`" "`tput sgr0`" "`tput sgr0`"
    let RESULT=1
  else
    STATUS="`curltry ${CURL} --fail --silent --location --user-agent \"${AGENT}\" \"https://app.vagrantup.com/api/v1/box/$1/$2/version/$4\" | jq -r '.status' 2>/dev/null`"
    LENGTH="`curltry ${CURL} --head --request GET --fail --silent --location --user-agent \"${AGENT}\" \"https://app.vagrantup.com/$1/boxes/$2/versions/$4/providers/$3.box\" 2>&1 | grep -a 'Content-Length' | awk -F': ' '{print \$2}' | tail -1`"

    if [ "$LENGTH" == "0" ]; then
      printf "%sBox  *   %s${1}/${2} ${3}%s \n%s" "`tput sgr0`" "`tput setaf 5`" "`tput sgr0`" "`tput sgr0`"
    elif [ "$STATUS" != "active" ]; then
      printf "%sBox  ~   %s${1}/${2} ${3}%s \n%s" "`tput sgr0`" "`tput setaf 3`" "`tput sgr0`" "`tput sgr0`"
    else
      printf "%sBox  +   %s${1}/${2} ${3}%s \n%s" "`tput sgr0`" "`tput setaf 2`" "`tput sgr0`" "`tput sgr0`"
    fi
  fi

  return $RESULT
}

# Build the boxes and cleanup the packer cache after each run.
function build() {

  verify_logdir
  export PACKER_LOG="1"
  unset LD_PRELOAD ; unset LD_LIBRARY_PATH ;
  [ -z "$PACKER_ON_ERROR" ] && export PACKER_ON_ERROR="cleanup"

  if [[ $OS == "Windows_NT" ]]; then
    export PACKER_LOG_PATH="$BASE/logs/$1-`date +'%Y%m%d.%H.%M.%S'`.txt"
    packer.exe build -on-error=$PACKER_ON_ERROR -parallel-builds=$PACKER_MAX_PROCS -except="${EXCEPTIONS}" $1.json
  else
    export PACKER_LOG_PATH="$BASE/logs/$1-`date +'%Y%m%d.%H.%M.%S'`.txt"
    packer build -on-error=$PACKER_ON_ERROR -parallel-builds=$PACKER_MAX_PROCS -except="${EXCEPTIONS}" $1.json
  fi

  if [[ $? != 0 ]]; then
    tput setaf 1; tput bold; printf "\n\n$1 images failed to build properly...\n\n"; tput sgr0

    # Auto retry any boxes that failed.
    which jq &> /dev/null
    if [[ $? == 0 ]]; then
      LIST=(`cat $1.json | jq -r " .builders | .[] |  .name " | sort`)
      for ((i = 0; i < ${#LIST[@]}; ++i)); do
        if [ ! -f "$BASE/output/${LIST[$i]}-$VERSION.box" ]; then
          export PACKER_LOG_PATH="$BASE/logs/$1-`date +'%Y%m%d.%H.%M.%S'`.txt"
          packer build -parallel-builds=$PACKER_MAX_PROCS -only="${LIST[$i]}" -except="${EXCEPTIONS}" $1.json
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
  unset LD_PRELOAD ; unset LD_LIBRARY_PATH ;
  [ -z "$PACKER_ON_ERROR" ] && export PACKER_ON_ERROR="cleanup"

  if [[ $OS == "Windows_NT" ]]; then

      export PACKER_LOG_PATH="$BASE/logs/magma-hyperv-log-`date +'%Y%m%d.%H.%M.%S'`.txt"
      [[ "$1" =~ ^.*magma.*$ ]] && [[ "$1" =~ ^.*hyperv.*$ ]] && packer.exe build -on-error=$PACKER_ON_ERROR -parallel-builds=$PACKER_MAX_PROCS -only=$1 magma-hyperv.json
      export PACKER_LOG_PATH="$BASE/logs/generic-hyperv-log-`date +'%Y%m%d.%H.%M.%S'`.txt"
      [[ "$1" =~ ^.*generic.*$ ]] && [[ "$1" =~ ^.*hyperv.*$ ]] && packer.exe build -on-error=$PACKER_ON_ERROR -parallel-builds=$PACKER_MAX_PROCS -only=$1 generic-hyperv.json
      export PACKER_LOG_PATH="$BASE/logs/lineage-hyperv-log-`date +'%Y%m%d.%H.%M.%S'`.txt"
      [[ "$1" =~ ^.*lineage.*$ ]] && [[ "$1" =~ ^.*hyperv.*$ ]] && packer.exe build -on-error=$PACKER_ON_ERROR -parallel-builds=$PACKER_MAX_PROCS -only=$1 lineage-hyperv.json
      export PACKER_LOG_PATH="$BASE/logs/developer-hyperv-log-`date +'%Y%m%d.%H.%M.%S'`.txt"
      [[ "$1" =~ ^.*developer.*$ ]] && [[ "$1" =~ ^.*hyperv.*$ ]] && packer.exe build -on-error=$PACKER_ON_ERROR -parallel-builds=$PACKER_MAX_PROCS -only=$1 developer-hyperv.json

  fi

  if [[ "$(uname)" == "Darwin" ]]; then

      export PACKER_LOG_PATH="$BASE/logs/generic-parallels-log-`date +'%Y%m%d.%H.%M.%S'`.txt"
      [[ "$1" =~ ^.*generic.*$ ]] && [[ "$1" =~ ^.*parallels.*$ ]] && packer build -on-error=$PACKER_ON_ERROR -parallel-builds=$PACKER_MAX_PROCS -only=$1 generic-parallels.json

  fi

  if [[ "$(uname)" == "Linux" ]]; then

      export PACKER_LOG_PATH="$BASE/logs/magma-docker-log-`date +'%Y%m%d.%H.%M.%S'`.txt"
      [[ "$1" =~ ^.*magma.*$ ]] && [[ "$1" =~ ^.*docker.*$ ]] && (docker-login && packer build -on-error=$PACKER_ON_ERROR -parallel-builds=$PACKER_MAX_PROCS -only=$1 magma-docker.json; docker-logout)
      export PACKER_LOG_PATH="$BASE/logs/magma-libvirt-log-`date +'%Y%m%d.%H.%M.%S'`.txt"
      [[ "$1" =~ ^.*magma.*$ ]] && [[ "$1" =~ ^.*libvirt.*$ ]] && packer build -on-error=$PACKER_ON_ERROR -parallel-builds=$PACKER_MAX_PROCS -only=$1 magma-libvirt.json

      export PACKER_LOG_PATH="$BASE/logs/generic-docker-log-`date +'%Y%m%d.%H.%M.%S'`.txt"
      [[ "$1" =~ ^.*generic.*$ ]] && [[ "$1" =~ ^.*docker.*$ ]] && (docker-login && packer build -on-error=$PACKER_ON_ERROR -parallel-builds=$PACKER_MAX_PROCS -only=$1 generic-docker.json; docker-logout)
      export PACKER_LOG_PATH="$BASE/logs/generic-libvirt-x32-log-`date +'%Y%m%d.%H.%M.%S'`.txt"
      [[ "$1" =~ ^.*generic.*$ ]] && [[ "$1" =~ ^.*x32-libvirt.*$ ]] && packer build -on-error=$PACKER_ON_ERROR -parallel-builds=$PACKER_MAX_PROCS -only=$1 generic-libvirt-x32.json
      export PACKER_LOG_PATH="$BASE/logs/generic-libvirt-log-`date +'%Y%m%d.%H.%M.%S'`.txt"
      [[ "$1" =~ ^.*generic.*$ ]] && [[ "$1" =~ ^.*libvirt.*$ ]] && packer build -on-error=$PACKER_ON_ERROR -parallel-builds=$PACKER_MAX_PROCS -only=$1 generic-libvirt.json

      export PACKER_LOG_PATH="$BASE/logs/developer-ova-log-`date +'%Y%m%d.%H.%M.%S'`.txt"
      [[ "$1" =~ ^.*developer.*$ ]] && [[ "$1" =~ ^.*ova.*$ ]] && packer build -on-error=$PACKER_ON_ERROR -parallel-builds=$PACKER_MAX_PROCS -only=$1 developer-ova.json
      export PACKER_LOG_PATH="$BASE/logs/developer-libvirt-log-`date +'%Y%m%d.%H.%M.%S'`.txt"
      [[ "$1" =~ ^.*developer.*$ ]] && [[ "$1" =~ ^.*libvirt.*$ ]] && packer build -on-error=$PACKER_ON_ERROR -parallel-builds=$PACKER_MAX_PROCS -only=$1 developer-libvirt.json

      export PACKER_LOG_PATH="$BASE/logs/lineage-libvirt-log-`date +'%Y%m%d.%H.%M.%S'`.txt"
      [[ "$1" =~ ^.*lineage.*$ ]] && [[ "$1" =~ ^.*libvirt.*$ ]] && packer build -on-error=$PACKER_ON_ERROR -parallel-builds=$PACKER_MAX_PROCS -only=$1 lineage-libvirt.json

  fi

  export PACKER_LOG_PATH="$BASE/logs/magma-vmware-log-`date +'%Y%m%d.%H.%M.%S'`.txt"
  [[ "$1" =~ ^.*magma.*$ ]] && [[ "$1" =~ ^.*vmware.*$ ]] && packer build -on-error=$PACKER_ON_ERROR -parallel-builds=$PACKER_MAX_PROCS -only=$1 magma-vmware.json
  export PACKER_LOG_PATH="$BASE/logs/magma-virtualbox-log-`date +'%Y%m%d.%H.%M.%S'`.txt"
  [[ "$1" =~ ^.*magma.*$ ]] && [[ "$1" =~ ^.*virtualbox.*$ ]] && packer build -on-error=$PACKER_ON_ERROR -parallel-builds=$PACKER_MAX_PROCS -only=$1 magma-virtualbox.json

  export PACKER_LOG_PATH="$BASE/logs/generic-vmware-log-`date +'%Y%m%d.%H.%M.%S'`.txt"
  [[ "$1" =~ ^.*generic.*$ ]] && [[ "$1" =~ ^.*vmware.*$ ]] && packer build -on-error=$PACKER_ON_ERROR -parallel-builds=$PACKER_MAX_PROCS -only=$1 generic-vmware.json
  export PACKER_LOG_PATH="$BASE/logs/generic-virtualbox-x32-log-`date +'%Y%m%d.%H.%M.%S'`.txt"
  [[ "$1" =~ ^.*generic.*$ ]] && [[ "$1" =~ ^.*x32-virtualbox.*$ ]] && packer build -on-error=$PACKER_ON_ERROR -parallel-builds=$PACKER_MAX_PROCS -only=$1 generic-virtualbox-x32.json
  export PACKER_LOG_PATH="$BASE/logs/generic-virtualbox-log-`date +'%Y%m%d.%H.%M.%S'`.txt"
  [[ "$1" =~ ^.*generic.*$ ]] && [[ "$1" =~ ^.*virtualbox.*$ ]] && packer build -on-error=$PACKER_ON_ERROR -parallel-builds=$PACKER_MAX_PROCS -only=$1 generic-virtualbox.json

  export PACKER_LOG_PATH="$BASE/logs/developer-vmware-log-`date +'%Y%m%d.%H.%M.%S'`.txt"
  [[ "$1" =~ ^.*developer.*$ ]] && [[ "$1" =~ ^.*vmware.*$ ]] && packer build -on-error=$PACKER_ON_ERROR -parallel-builds=$PACKER_MAX_PROCS -only=$1 developer-vmware.json
  export PACKER_LOG_PATH="$BASE/logs/developer-virtualbox-log-`date +'%Y%m%d.%H.%M.%S'`.txt"
  [[ "$1" =~ ^.*developer.*$ ]] && [[ "$1" =~ ^.*virtualbox.*$ ]] && packer build -on-error=$PACKER_ON_ERROR -parallel-builds=$PACKER_MAX_PROCS -only=$1 developer-virtualbox.json

  export PACKER_LOG_PATH="$BASE/logs/lineage-vmware-log-`date +'%Y%m%d.%H.%M.%S'`.txt"
  [[ "$1" =~ ^.*lineage.*$ ]] && [[ "$1" =~ ^.*vmware.*$ ]] && packer build -on-error=$PACKER_ON_ERROR -parallel-builds=$PACKER_MAX_PROCS -only=$1 lineage-vmware.json
  export PACKER_LOG_PATH="$BASE/logs/lineage-virtualbox-log-`date +'%Y%m%d.%H.%M.%S'`.txt"
  [[ "$1" =~ ^.*lineage.*$ ]] && [[ "$1" =~ ^.*virtualbox.*$ ]] && packer build -on-error=$PACKER_ON_ERROR -parallel-builds=$PACKER_MAX_PROCS -only=$1 lineage-virtualbox.json

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
  
  for ((i = 0; i < ${#REPOS[@]}; ++i)); do
    (verify_url "${REPOS[$i]}") &
    sleep 0.1 &> /dev/null || echo "" &> /dev/null
  done

  # Wait until the children are done working.
  wait

  # Detect downloads that aren't being fetched by the packer-cache.json file.
  for ((i = 0; i < ${#ISOURLS[@]}; ++i)); do
    grep --silent "${ISOURLS[$i]}" packer-cache.json ||
      echo "Cache Failure:  ${ISOURLS[$i]}"
  done

  for ((i = 0; i < ${#ISOSUMS[@]}; ++i)); do
    grep --silent "${ISOSUMS[$i]}" packer-cache.json ||
      echo "Cache Failure:  ${ISOSUMS[$i]}"
  done

  # Combine the media URLs with the regular box ISO URLs and the repos.
  let TOTAL=${#UNIQURLS[@]}+${#MURLS[@]}+${#REPOS[@]}

  # Let the user know all of the links passed.
  printf "\nAll $TOTAL of the install media/package repository locations have been checked...\n\n"
}

function sums() {

  [ ! -n "$JOBS" ] && export JOBS="32"

  # for ((i = 0; i < ${#ISOURLS[@]}; ++i)); do
  #     verify_sum "${ISOURLS[$i]}" "${ISOSUMS[$i]}"
  # done

  export -f verify_sum
  parallel --jobs $JOBS --delay 1 --line-buffer --shuf --xapply verify_sum {1} {2} ":::" "${ISOURLS[@]}" ":::" "${ISOSUMS[@]}"

  # Let the user know all of the links passed.
  # printf "\nAll ${#ISOURLS[@]} of the install media locations have been validated...\n\n"
}

function validate() {
  verify_json packer-cache && printf "The packer-cache.json file is valid.\n"
  verify_json magma-docker && printf "The magma-docker.json file is valid.\n"
  verify_json magma-hyperv && printf "The magma-hyperv.json file is valid.\n"
  verify_json magma-vmware && printf "The magma-vmware.json file is valid.\n"
  verify_json magma-libvirt && printf "The magma-libvirt.json file is valid.\n"
  verify_json magma-virtualbox && printf "The magma-virtualbox.json file is valid.\n"
  verify_json generic-docker && printf "The generic-docker.json file is valid.\n"
  verify_json generic-hyperv && printf "The generic-hyperv.json file is valid.\n"
  verify_json generic-vmware && printf "The generic-vmware.json file is valid.\n"
  verify_json generic-libvirt && printf "The generic-libvirt.json file is valid.\n"
  verify_json generic-libvirt-x32 && printf "The generic-libvirt-x32.json file is valid.\n"
  verify_json generic-parallels && printf "The generic-parallels.json file is valid.\n"
  verify_json generic-virtualbox && printf "The generic-virtualbox.json file is valid.\n"
  verify_json generic-virtualbox-x32 && printf "The generic-virtualbox-x32.json file is valid.\n"
  verify_json developer-ova && printf "The developer-ova.json file is valid.\n"
  verify_json developer-hyperv && printf "The developer-hyperv.json file is valid.\n"
  verify_json developer-vmware && printf "The developer-vmware.json file is valid.\n"
  verify_json developer-libvirt && printf "The developer-libvirt.json file is valid.\n"
  verify_json developer-virtualbox && printf "The developer-virtualbox.json file is valid.\n"
  verify_json lineage-hyperv && printf "The lineage-hyperv.json file is valid.\n"
  verify_json lineage-vmware && printf "The lineage-vmware.json file is valid.\n"
  verify_json lineage-libvirt && printf "The lineage-libvirt.json file is valid.\n"
  verify_json lineage-virtualbox && printf "The lineage-virtualbox.json file is valid.\n"
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
    UNRELEASED=0
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
          ${CURL} --head --silent --location --user-agent "${AGENT}" "https://app.vagrantup.com/${ORGANIZATION}/boxes/${BOX}/versions/${VERSION}/providers/${PROVIDER}.box?access_token=${VAGRANT_CLOUD_TOKEN}" | head -1 | grep --silent --extended-regexp "HTTP/1\.1 200 OK|HTTP/2\.0 200 OK|HTTP/2 200|HTTP/1\.1 302 Found|HTTP/2.0 302 Found|HTTP/2 302 Found"

          if [ $? != 0 ]; then
            let MISSING+=1
            printf "Box  -  "; tput setaf 1; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
          else
            let FOUND+=1
            STATUS="`curltry ${CURL} --fail --silent --location --user-agent \"${AGENT}\" \"https://app.vagrantup.com/api/v1/box/${ORGANIZATION}/${BOX}/version/${VERSION}?access_token=${VAGRANT_CLOUD_TOKEN}\" | jq -r '.status' 2>/dev/null`"

           if [ "$STATUS" != "active" ]; then
              let UNRELEASED+=1
              printf "Box  ~  "; tput setaf 3; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
            else
              printf "Box  +  "; tput setaf 2; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
            fi
          fi
        fi
      fi

      PROVIDER="hyperv"
      if [[ "${ORGANIZATION}" =~ ^(generic|roboxes|lavabit|lineage|lineageos)$ ]]; then
        ${CURL} --head --silent --location --user-agent "${AGENT}" "https://app.vagrantup.com/${ORGANIZATION}/boxes/${BOX}/versions/${VERSION}/providers/${PROVIDER}.box?access_token=${VAGRANT_CLOUD_TOKEN}" | head -1 | grep --silent --extended-regexp "HTTP/1\.1 200 OK|HTTP/2\.0 200 OK|HTTP/2 200|HTTP/1\.1 302 Found|HTTP/2.0 302 Found|HTTP/2 302 Found"

        if [ $? != 0 ]; then
          let MISSING+=1
          printf "Box  -  "; tput setaf 1; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
        else
          let FOUND+=1
          STATUS="`curltry ${CURL} --fail --silent --location --user-agent \"${AGENT}\" \"https://app.vagrantup.com/api/v1/box/${ORGANIZATION}/${BOX}/version/${VERSION}?access_token=${VAGRANT_CLOUD_TOKEN}\" | jq -r '.status' 2>/dev/null`"

          if [ "$STATUS" != "active" ]; then
            let UNRELEASED+=1
            printf "Box  ~  "; tput setaf 3; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
          else
            printf "Box  +  "; tput setaf 2; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
          fi
        fi
      fi

      PROVIDER="libvirt"
      ${CURL} --head --silent --location --user-agent "${AGENT}" "https://app.vagrantup.com/${ORGANIZATION}/boxes/${BOX}/versions/${VERSION}/providers/${PROVIDER}.box?access_token=${VAGRANT_CLOUD_TOKEN}" | head -1 | grep --silent --extended-regexp "HTTP/1\.1 200 OK|HTTP/2\.0 200 OK|HTTP/2 200|HTTP/1\.1 302 Found|HTTP/2.0 302 Found|HTTP/2 302 Found"

      if [ $? != 0 ]; then
        let MISSING+=1
        printf "Box  -  "; tput setaf 1; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
      else
        let FOUND+=1
        STATUS="`curltry ${CURL} --fail --silent --location --user-agent \"${AGENT}\" \"https://app.vagrantup.com/api/v1/box/${ORGANIZATION}/${BOX}/version/${VERSION?access_token=${VAGRANT_CLOUD_TOKEN}\" | jq -r '.status' 2>/dev/null`"

        if [ "$STATUS" != "active" ]; then
          let UNRELEASED+=1
          printf "Box  ~  "; tput setaf 3; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
        else
          printf "Box  +  "; tput setaf 2; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
        fi
      fi

      PROVIDER="parallels"
      if [[ "${ORGANIZATION}" =~ ^(generic|roboxes)$ ]]; then
        ${CURL} --head --silent --location --user-agent "${AGENT}" "https://app.vagrantup.com/${ORGANIZATION}/boxes/${BOX}/versions/${VERSION}/providers/${PROVIDER}.box?access_token=${VAGRANT_CLOUD_TOKEN}" | head -1 | grep --silent --extended-regexp "HTTP/1\.1 200 OK|HTTP/2\.0 200 OK|HTTP/2 200|HTTP/1\.1 302 Found|HTTP/2.0 302 Found|HTTP/2 302 Found"

        if [ $? != 0 ]; then
          let MISSING+=1
          printf "Box  -  "; tput setaf 1; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
        else
          let FOUND+=1
          STATUS="`curltry ${CURL} --fail --silent --location --user-agent \"${AGENT}\" \"https://app.vagrantup.com/api/v1/box/${ORGANIZATION}/${BOX}/version/${VERSION}?access_token=${VAGRANT_CLOUD_TOKEN}\" | jq -r '.status' 2>/dev/null`"

          if [ "$STATUS" != "active" ]; then
            let UNRELEASED+=1
            printf "Box  ~  "; tput setaf 3; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
          else
            printf "Box  +  "; tput setaf 2; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
          fi
        fi
      fi

      PROVIDER="virtualbox"
      ${CURL} --head --silent --location --user-agent "${AGENT}" "https://app.vagrantup.com/${ORGANIZATION}/boxes/${BOX}/versions/${VERSION}/providers/${PROVIDER}.box?access_token=${VAGRANT_CLOUD_TOKEN}" | head -1 | grep --silent --extended-regexp "HTTP/1\.1 200 OK|HTTP/2\.0 200 OK|HTTP/2 200|HTTP/1\.1 302 Found|HTTP/2.0 302 Found|HTTP/2 302 Found"

      if [ $? != 0 ]; then
        let MISSING+=1
        printf "Box  -  "; tput setaf 1; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
      else
        let FOUND+=1
        STATUS="`curltry ${CURL} --fail --silent --location --user-agent \"${AGENT}\" \"https://app.vagrantup.com/api/v1/box/${ORGANIZATION}/${BOX}/version/${VERSION}?access_token=${VAGRANT_CLOUD_TOKEN}\" | jq -r '.status' 2>/dev/null`"

        if [ "$STATUS" != "active" ]; then
          let UNRELEASED+=1
          printf "Box  ~  "; tput setaf 3; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
        else
          printf "Box  +  "; tput setaf 2; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
        fi
      fi

      PROVIDER="vmware_desktop"
      if [[ "${ORGANIZATION}" =~ ^(generic|roboxes|lavabit|lineage|lineageos)$ ]]; then
        ${CURL} --head --silent --location --user-agent "${AGENT}" "https://app.vagrantup.com/${ORGANIZATION}/boxes/${BOX}/versions/${VERSION}/providers/${PROVIDER}.box?access_token=${VAGRANT_CLOUD_TOKEN}" | head -1 | grep --silent --extended-regexp "HTTP/1\.1 200 OK|HTTP/2\.0 200 OK|HTTP/2 200|HTTP/1\.1 302 Found|HTTP/2.0 302 Found|HTTP/2 302 Found"

        if [ $? != 0 ]; then
          let MISSING+=1
          printf "Box  -  "; tput setaf 1; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
        else
          let FOUND+=1
          STATUS="`curltry ${CURL} --fail --silent --location --user-agent \"${AGENT}\" \"https://app.vagrantup.com/api/v1/box/${ORGANIZATION}/${BOX}/version/${VERSION}?access_token=${VAGRANT_CLOUD_TOKEN}\" | jq -r '.status' 2>/dev/null`"

          if [ "$STATUS" != "active" ]; then
            let UNRELEASED+=1
            printf "Box  ~  "; tput setaf 3; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
          else
            printf "Box  +  "; tput setaf 2; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
          fi
        fi
      fi

      # Limit requests to ~100 per minute to avoid stalls.
      sleep 1.2 &> /dev/null || echo "" &> /dev/null

    done

    # Get the totla number of boxes.
    let TOTAL=${FOUND}+${MISSING}
    let FOUND=${TOTAL}-${MISSING}

    # Let the user know how many boxes were missing.
    if [ $MISSING -eq 0 ] && [ $UNRELEASED -eq 0 ]; then
      printf "\nAll ${TOTAL} of the boxes are available...\n\n"
    elif [ $UNRELEASED -eq 0 ]; then
      printf "\nOf the ${TOTAL} boxes defined, ${FOUND} are available, ${MISSING} are unavailable...\n\n"
    else
      printf "\nOf the ${TOTAL} boxes defined, ${FOUND} are available, with ${UNRELEASED} unreleased, and ${MISSING} unavailable...\n\n"
    fi
}

function public() {

    FOUND=0
    MISSING=0
    UNRELEASED=0
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
            STATUS="`curltry ${CURL} --fail --silent --location --user-agent \"${AGENT}\" \"https://app.vagrantup.com/api/v1/box/${ORGANIZATION}/${BOX}/version/${VERSION}\" | jq -r '.status' 2>/dev/null`"

            if [ "$STATUS" != "active" ]; then
              let UNRELEASED+=1
              printf "Box  ~  "; tput setaf 3; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
            else
              printf "Box  +  "; tput setaf 2; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
            fi
          fi
        fi
      fi

      PROVIDER="hyperv"
      if [[ "${ORGANIZATION}" =~ ^(generic|roboxes|lavabit|lineage|lineageos)$ ]]; then
        curltry ${CURL} --head --fail --silent --location --user-agent "${AGENT}" --output /dev/null --write-out "%{http_code}" "https://app.vagrantup.com/${ORGANIZATION}/boxes/${BOX}/versions/${VERSION}/providers/${PROVIDER}.box" | grep --silent "200"

        if [ $? != 0 ]; then
          let MISSING+=1
          printf "Box  -  "; tput setaf 1; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
        else
          let FOUND+=1
          STATUS="`curltry ${CURL} --fail --silent --location --user-agent \"${AGENT}\" \"https://app.vagrantup.com/api/v1/box/${ORGANIZATION}/${BOX}/version/${VERSION}\" | jq -r '.status' 2>/dev/null`"

          if [ "$STATUS" != "active" ]; then
            let UNRELEASED+=1
            printf "Box  ~  "; tput setaf 3; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
          else
            printf "Box  +  "; tput setaf 2; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
          fi
        fi
      fi

      PROVIDER="libvirt"
      curltry ${CURL} --head --fail --silent --location --user-agent "${AGENT}" --output /dev/null --write-out "%{http_code}" "https://app.vagrantup.com/${ORGANIZATION}/boxes/${BOX}/versions/${VERSION}/providers/${PROVIDER}.box" | grep --silent "200"

      if [ $? != 0 ]; then
        let MISSING+=1
        printf "Box  -  "; tput setaf 1; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
      else
        let FOUND+=1
        STATUS="`curltry ${CURL} --fail --silent --location --user-agent \"${AGENT}\" \"https://app.vagrantup.com/api/v1/box/${ORGANIZATION}/${BOX}/version/${VERSION}\" | jq -r '.status' 2>/dev/null`"

        if [ "$STATUS" != "active" ]; then
          let UNRELEASED+=1
          printf "Box  ~  "; tput setaf 3; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
        else
          printf "Box  +  "; tput setaf 2; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
        fi
      fi

      PROVIDER="parallels"
      if [[ "${ORGANIZATION}" =~ ^(generic|roboxes)$ ]]; then
        curltry ${CURL} --head --fail --silent --location --user-agent "${AGENT}" --output /dev/null --write-out "%{http_code}" "https://app.vagrantup.com/${ORGANIZATION}/boxes/${BOX}/versions/${VERSION}/providers/${PROVIDER}.box" | grep --silent "200"

        if [ $? != 0 ]; then
          let MISSING+=1
          printf "Box  -  "; tput setaf 1; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
        else
          let FOUND+=1
          STATUS="`curltry ${CURL} --fail --silent --location --user-agent \"${AGENT}\" \"https://app.vagrantup.com/api/v1/box/${ORGANIZATION}/${BOX}/version/${VERSION}\" | jq -r '.status' 2>/dev/null`"

          if [ "$STATUS" != "active" ]; then
            let UNRELEASED+=1
            printf "Box  ~  "; tput setaf 3; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
          else
            printf "Box  +  "; tput setaf 2; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
          fi
        fi
      fi

      PROVIDER="virtualbox"
      curltry ${CURL} --head --fail --silent --location --user-agent "${AGENT}" --output /dev/null --write-out "%{http_code}" "https://app.vagrantup.com/${ORGANIZATION}/boxes/${BOX}/versions/${VERSION}/providers/${PROVIDER}.box" | grep --silent "200"

      if [ $? != 0 ]; then
        let MISSING+=1
        printf "Box  -  "; tput setaf 1; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
      else
        let FOUND+=1
        STATUS="`curltry ${CURL} --fail --silent --location --user-agent \"${AGENT}\" \"https://app.vagrantup.com/api/v1/box/${ORGANIZATION}/${BOX}/version/${VERSION}\" | jq -r '.status' 2>/dev/null`"

        if [ "$STATUS" != "active" ]; then
          let UNRELEASED+=1
          printf "Box  ~  "; tput setaf 3; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
        else
          printf "Box  +  "; tput setaf 2; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
        fi
      fi

      PROVIDER="vmware_desktop"
      if [[ "${ORGANIZATION}" =~ ^(generic|roboxes|lavabit|lineage|lineageos)$ ]]; then
        curltry ${CURL} --head --fail --silent --location --user-agent "${AGENT}" --output /dev/null --write-out "%{http_code}" "https://app.vagrantup.com/${ORGANIZATION}/boxes/${BOX}/versions/${VERSION}/providers/${PROVIDER}.box" | grep --silent "200"

        if [ $? != 0 ]; then
          let MISSING+=1
          printf "Box  -  "; tput setaf 1; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
        else
          let FOUND+=1
          STATUS="`curltry ${CURL} --fail --silent --location --user-agent \"${AGENT}\" \"https://app.vagrantup.com/api/v1/box/${ORGANIZATION}/${BOX}/version/${VERSION}\" | jq -r '.status' 2>/dev/null`"

          if [ "$STATUS" != "active" ]; then
            let UNRELEASED+=1
            printf "Box  ~  "; tput setaf 3; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
          else
            printf "Box  +  "; tput setaf 2; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
          fi
        fi
      fi

      # Limit requests to ~100 per minute to avoid stalls.
      sleep 1.2 &> /dev/null || echo "" &> /dev/null

    done

    # Get the totla number of boxes.
    let TOTAL=${FOUND}+${MISSING}
    let FOUND=${TOTAL}-${MISSING}

    # Let the user know how many boxes were missing.
    if [ $MISSING -eq 0 ] && [ $UNRELEASED -eq 0 ]; then
      printf "\nAll ${TOTAL} of the boxes are available...\n\n"
    elif [ $UNRELEASED -eq 0 ]; then
      printf "\nOf the ${TOTAL} boxes defined, ${FOUND} are available, ${MISSING} are unavailable...\n\n"
    else
      printf "\nOf the ${TOTAL} boxes defined, ${FOUND} are available, with ${UNRELEASED} unreleased, and ${MISSING} unavailable...\n\n"
    fi
}

function ppublic() {

    FOUND=0
    MISSING=0
    LIST=($TAGS)
    FILTER=($FILTERED_TAGS)
    [ ! -n "$JOBS" ] && export JOBS="192"

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
      PROVIDER="hyperv"
      if [[ "${ORGANIZATION}" =~ ^(generic|roboxes|lavabit|lineage|lineageos)$ ]]; then
        O=( "${O[@]}" "${ORGANIZATION}" ); B=( "${B[@]}" "${BOX}" ); P=( "${P[@]}" "${PROVIDER}" ); V=( "${V[@]}" "${VERSION}" );
      fi

      PROVIDER="libvirt"
      O=( "${O[@]}" "${ORGANIZATION}" ); B=( "${B[@]}" "${BOX}" ); P=( "${P[@]}" "${PROVIDER}" ); V=( "${V[@]}" "${VERSION}" );

      PROVIDER="parallels"
      if [[ "${ORGANIZATION}" =~ ^(generic|roboxes)$ ]]; then
        O=( "${O[@]}" "${ORGANIZATION}" ); B=( "${B[@]}" "${BOX}" ); P=( "${P[@]}" "${PROVIDER}" ); V=( "${V[@]}" "${VERSION}" );
      fi

      PROVIDER="virtualbox"
      O=( "${O[@]}" "${ORGANIZATION}" ); B=( "${B[@]}" "${BOX}" ); P=( "${P[@]}" "${PROVIDER}" ); V=( "${V[@]}" "${VERSION}" );

      PROVIDER="vmware_desktop"
      PROVIDER="hyperv"
      if [[ "${ORGANIZATION}" =~ ^(generic|roboxes|lavabit|lineage|lineageos)$ ]]; then
        O=( "${O[@]}" "${ORGANIZATION}" ); B=( "${B[@]}" "${BOX}" ); P=( "${P[@]}" "${PROVIDER}" ); V=( "${V[@]}" "${VERSION}" );
      fi

    done

    export -f curltry ; export -f verify_availability ; export CURL ;
    # parallel --jobs $JOBS --keep-order --xapply verify_availability {1} {2} {3} {4} ":::" "${O[@]}" ":::" "${B[@]}" ":::" "${P[@]}" ":::" "${V[@]}"
    parallel --jobs $JOBS --delay 1 --keep-order --line-buffer --xapply verify_availability {1} {2} {3} {4} '||' let MISSING+=1 ":::" "${O[@]}" ":::" "${B[@]}" ":::" "${P[@]}" ":::" "${V[@]}"
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

function invalid() {

    TOTAL=0
    INVALID=0
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
          LENGTH="`curltry ${CURL} --head --request GET --fail --silent --location --user-agent \"${AGENT}\" \"https://app.vagrantup.com/${ORGANIZATION}/boxes/${BOX}/versions/${VERSION}/providers/${PROVIDER}.box\" 2>&1 | grep -a 'Content-Length' | awk -F': ' '{print \$2}' | tail -1`"

          if [ "$LENGTH" == "0" ]; then
            let TOTAL+=1
            let INVALID+=1
            printf "Box  *  "; tput setaf 5; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
          else
            let TOTAL+=1
          fi
        fi
      fi

      PROVIDER="hyperv"
      if [[ "${ORGANIZATION}" =~ ^(generic|roboxes|lavabit|lineage|lineageos)$ ]]; then
        LENGTH="`curltry ${CURL} --head --request GET --fail --silent --location --user-agent \"${AGENT}\" \"https://app.vagrantup.com/${ORGANIZATION}/boxes/${BOX}/versions/${VERSION}/providers/${PROVIDER}.box\" 2>&1 | grep -a 'Content-Length' | awk -F': ' '{print \$2}' | tail -1`"

        if [ "$LENGTH" == "0" ]; then
          let TOTAL+=1
          let INVALID+=1
          printf "Box  *  "; tput setaf 5; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
        else
          let TOTAL+=1
        fi
      fi

      PROVIDER="libvirt"
      LENGTH="`curltry ${CURL} --head --request GET --fail --silent --location --user-agent \"${AGENT}\" \"https://app.vagrantup.com/${ORGANIZATION}/boxes/${BOX}/versions/${VERSION}/providers/${PROVIDER}.box\" 2>&1 | grep -a 'Content-Length' | awk -F': ' '{print \$2}' | tail -1`"

      if [ "$LENGTH" == "0" ]; then
        let TOTAL+=1
        let INVALID+=1
        printf "Box  *  "; tput setaf 5; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
      else
        let TOTAL+=1
      fi

      PROVIDER="parallels"
      if [[ "${ORGANIZATION}" =~ ^(generic|roboxes)$ ]]; then
        LENGTH="`curltry ${CURL} --head --request GET --fail --silent --location --user-agent \"${AGENT}\" \"https://app.vagrantup.com/${ORGANIZATION}/boxes/${BOX}/versions/${VERSION}/providers/${PROVIDER}.box\" 2>&1 | grep -a 'Content-Length' | awk -F': ' '{print \$2}' | tail -1`"

        if [ "$LENGTH" == "0" ]; then
          let TOTAL+=1
          let INVALID+=1
          printf "Box  *  "; tput setaf 5; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
        else
          let TOTAL+=1
        fi
      fi

      PROVIDER="virtualbox"
      LENGTH="`curltry ${CURL} --head --request GET --fail --silent --location --user-agent \"${AGENT}\" \"https://app.vagrantup.com/${ORGANIZATION}/boxes/${BOX}/versions/${VERSION}/providers/${PROVIDER}.box\" 2>&1 | grep -a 'Content-Length' | awk -F': ' '{print \$2}' | tail -1`"

      if [ "$LENGTH" == "0" ]; then
        let TOTAL+=1
        let INVALID+=1
        printf "Box  *  "; tput setaf 5; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
      else
        let TOTAL+=1
      fi

      PROVIDER="vmware_desktop"
      if [[ "${ORGANIZATION}" =~ ^(generic|roboxes|lavabit|lineage|lineageos)$ ]]; then
        LENGTH="`curltry ${CURL} --head --request GET --fail --silent --location --user-agent \"${AGENT}\" \"https://app.vagrantup.com/${ORGANIZATION}/boxes/${BOX}/versions/${VERSION}/providers/${PROVIDER}.box\" 2>&1 | grep -a 'Content-Length' | awk -F': ' '{print \$2}' | tail -1`"

        if [ "$LENGTH" == "0" ]; then
          let TOTAL+=1
          let INVALID+=1
          printf "Box  *  "; tput setaf 5; printf "${LIST[$i]} ${PROVIDER}\n"; tput sgr0
        else
          let TOTAL+=1
        fi
      fi

      # Limit requests to ~100 per minute to avoid stalls.
      sleep 0.6 &> /dev/null || echo "" &> /dev/null
    done

    # Let the user know how many boxes were missing.
    if [ $INVALID -eq 0 ]; then
      printf "\nAll ${TOTAL} of the boxes are available...\n\n"
    else
      printf "\nOf the ${TOTAL} boxes defined, ${INVALID} have an invalid size...\n\n"
    fi
}

function grab() {

  if [ $# -ne 3 ]; then
    tput setaf 1; printf "\n\n  Usage:\n    $(basename $0) grab ORG BOX PROVIDER\n\n\n"; tput sgr0
    exit 1
  fi

  URL=`${CURL} --fail --silent --location --user-agent "${AGENT}" "https://app.vagrantup.com/api/v1/box/$1/$2" \
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
  rm -rf $BASE/output/ $BASE/logs/
}

function distclean() {

  # The typical cleanup.
  rm -rf $BASE/packer_cache/ $BASE/output/ $BASE/logs/

  printf "\nThe distclean target will purge status information across the entire system.\n" ; \
  tput setaf 1; tput bold;  printf "Be very careful. This message will self-destruct in thirty seconds.\n" ; tput sgr0
  read -t 30 -r -p "Would you like to continue? [y/N]: " RESPONSE
  RESPONSE=${RESPONSE,,}
  if [[ ! $RESPONSE =~ ^(yes|y) ]]; then
    exit 1
  fi

  # If VMWare is installed.
  if [ "$(command -v vmrun)" ]; then
    unset LD_PRELOAD ; unset LD_LIBRARY_PATH
    vmrun -T ws list | grep -v "Total running VMs:" | while read VMX ; do
      vmrun -T ws stop "$VMX" hard
      vmrun -T ws deleteVM "$VMX"
    done
  fi

  # If VirtualBox is installed.
  if [ "$(command -v vboxmanage)" ]; then
    vboxmanage list vms | awk -F' ' '{print $2}' | while read UUID ; do
      vboxmanage controlvm "$UUID" poweroff &> /dev/null
      vboxmanage unregistervm "$UUID" --delete &> /dev/null
    done
  fi

  # If libvirt is installed.
  if [ "$(command -v virsh)" ]; then

    # If the description indicates the VM was created by Vagrant we remove it.
    virsh --connect=qemu:///system list --name --all | grep -vE "^\$" | while read DOMNAME ; do
      if [ "$(virsh --connect=qemu:///system desc --domain $DOMNAME | grep -E '/Vagrantfile$')" ]; then
        virsh --connect=qemu:///system destroy --domain $DOMNAME &> /dev/null
        virsh --connect=qemu:///system undefine --domain $DOMNAME --remove-all-storage --delete-snapshots &> /dev/null
      fi
    done

    # We look for volumes that appear to be base images, or whose name matches the default naming convention used by Vagrant.
    virsh --connect=qemu:///system vol-list default | awk -F' ' '{print $2}' | grep -vE "^\$|^Path\$" | while read VOLNAME ; do
      if [ "$(echo $VOLNAME | grep -E '\/(generic|roboxes|lavabit|lineage|lineageos)\-VAGRANTSLASH\-.*\_box\.img$')" ]; then
        virsh --connect=qemu:///system vol-delete --pool default $VOLNAME &> /dev/null
      elif [ "$(echo $VOLNAME | grep -E '\/(generic|roboxes|lavabit\-magma|lineage|lineageos)\-.*\-libvirt\_default\.img')" ]; then
        virsh --connect=qemu:///system vol-delete --pool default $VOLNAME &> /dev/null
      fi
    done

    virsh --connect=qemu:///system net-list --name --all | grep -vE "^\$" | while read NETNAME ; do
      if [ "$(echo $NETNAME | grep -E '^vagrant\-')" ]; then
        virsh --connect=qemu:///system net-destroy --network $NETNAME &> /dev/null
        virsh --connect=qemu:///system net-undefine --network $NETNAME &> /dev/null
      fi
    done
  fi

  # If Docker is installed.
  if [ "$(command -v docker-latest)" ]; then
    docker-latest ps --all --quiet | while read UUID ; do
      docker-latest rm --force $UUID &> /dev/null
    done
    docker-latest images --all --quiet | while read UUID ; do
      docker rmi --force $UUID &> /dev/null
    done
  elif [ "$(command -v docker)" ]; then
    docker ps --all --quiet | while read UUID ; do
      docker rm --force $UUID &> /dev/null
    done
    docker images --all --quiet | while read UUID ; do
      docker rmi --force $UUID &> /dev/null
    done
  fi

  sudo killall -9 /usr/bin/docker-containerd-shim-latest &> /dev/null
  sudo killall -9 docker-containerd-shim-latest &> /dev/null

  sudo killall -9 /usr/lib/vmware/bin/vmware-vmx &> /dev/null
  sudo killall -9 killall vmware-vmx &> /dev/null

  sudo killall -9 /usr/lib/virtualbox/VBoxHeadless &> /dev/null
  sudo killall -9 VBoxHeadless &> /dev/null

  sudo killall -9 /usr/libexec/qemu-kvm &> /dev/null
  sudo killall -9 qemu-kvm &> /dev/null

  sudo truncate --size=0 /etc/vmware/vmnet1/dhcpd/dhcpd.leases
  sudo truncate --size=0 /etc/vmware/vmnet8/dhcpd/dhcpd.lease

  [ -d $HOME/.vmware/ ] && rm -rf $HOME/.vmware/
  [ -d $HOME/.packer.d/ ] && rm -rf $HOME/.packer.d/
  [ -d $HOME/.vagrant.d/ ] && rm -rf $HOME/.vagrant.d/
  [ -d $HOME/.cache/libvirt/ ] && rm -rf $HOME/.cache/libvirt/
  [ -d $HOME/.config/libvirt/ ] && rm -rf $HOME/.config/libvirt/
  [ -d $HOME/.VirtualBox\ VMs/ ] && rm -rf $HOME/VirtualBox\ VMs/

  if [ -f /etc/init.d/vmware ]; then sudo /etc/init.d/vmware start ; fi
  if [ -f /etc/init.d/vmware-USBArbitrator ]; then sudo /etc/init.d/vmware-USBArbitrator start ; fi
  if [ -f /etc/init.d/vmware-workstation-server ]; then sudo /etc/init.d/vmware-workstation-server start ; fi
  if [ -f /usr/lib/systemd/system/vboxdrv.service ]; then sudo systemctl restart vboxdrv.service ; fi
  if [ -f /usr/lib/systemd/system/libvirtd.service ]; then sudo systemctl restart libvirtd.service ; fi
  if [ -f /usr/lib/systemd/system/docker-latest.service ]; then sudo systemctl restart docker-latest.service ;
  elif [ -f /usr/lib/systemd/system/docker.service ]; then sudo systemctl restart docker.service ; fi

  if [ -f /opt/vagrant-vmware-desktop/bin/vagrant-vmware-utility ]; then
    sudo systemctl stop vagrant-vmware-utility.service &> /dev/null
    sudo /opt/vagrant-vmware-desktop/bin/vagrant-vmware-utility service uninstall &> /dev/null

    [ -f /opt/vagrant-vmware-desktop/settings/nat.json ] && sudo rm -f /opt/vagrant-vmware-desktop/settings/nat.json
    [ -f /opt/vagrant-vmware-desktop/settings/portforwarding.json ] && sudo rm -f /opt/vagrant-vmware-desktop/settings/portforwarding.json
    [ -f /opt/vagrant-vmware-desktop/certificates/vagrant-utility.client.crt ] && sudo rm -f /opt/vagrant-vmware-desktop/certificates/vagrant-utility.client.crt
    [ -f /opt/vagrant-vmware-desktop/certificates/vagrant-utility.client.key ] && sudo rm -f /opt/vagrant-vmware-desktop/certificates/vagrant-utility.client.key
    [ -f /opt/vagrant-vmware-desktop/certificates/vagrant-utility.crt ] && sudo rm -f /opt/vagrant-vmware-desktop/certificates/vagrant-utility.crt
    [ -f /opt/vagrant-vmware-desktop/certificates/vagrant-utility.key ] && sudo rm -f /opt/vagrant-vmware-desktop/certificates/vagrant-utility.key

    sudo /opt/vagrant-vmware-desktop/bin/vagrant-vmware-utility certificate generate &> /dev/null
    sudo /opt/vagrant-vmware-desktop/bin/vagrant-vmware-utility service install &> /dev/null
    sudo systemctl restart vagrant-vmware-utility.service &> /dev/null
  elif [ -f /etc/systemd/system/vagrant-vmware-utility.service ]; then
    sudo systemctl restart vagrant-vmware-utility.service &> /dev/null
  elif [ -f /etc/init.d/vagrant-vmware-utility ]; then
    sudo /etc/init.d/vagrant-vmware-utility restart &> /dev/null
  fi

}

function docker-login() {

  # If jq is installed, we can use it to determine whether a login is required. Otherwise we rely on the more primitive login logic.
  if [ -f /usr/bin/jq ] || [ -f /usr/local/bin/jq ]; then
    if [[ `jq "[ .auths.\"quay.io\" ]" ~/.docker/config.json | jq " .[] | length"` == 0 ]]; then
      docker login -u "$QUAY_USER" -p "$QUAY_PASSWORD" quay.io
      if [[ $? != 0 ]]; then
        tput setaf 1; tput bold; printf "\n\nThe quay.io login credentials failed.\n\n"; tput sgr0
        read -t 30 -r -p "Would you like to continue? [Y/n]: " RESPONSE
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
        read -t 30 -r -p "Would you like to continue? [Y/n]: " RESPONSE
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
        read -t 30 -r -p "Would you like to continue? [Y/n]: " RESPONSE

        RESPONSE=${RESPONSE,,}
        if [[ ! $RESPONSE =~ ^(yes|y| ) ]] && [[ ! -z $RESPONSE ]]; then
          exit 1
        fi
      fi

      docker login -u "$DOCKER_USER" -p "$DOCKER_PASSWORD" docker.io
      if [[ $? != 0 ]]; then
        tput setaf 1; tput bold; printf "\n\nThe docker.io login credentials failed.\n\n"; tput sgr0
        read -t 30 -r -p "Would you like to continue? [Y/n]: " RESPONSE
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
  elif [[ "$(uname)" == "Darwin" ]]; then
    build generic-parallels
  else
    build generic-vmware
    build generic-libvirt
    build generic-libvirt-x32
    build generic-virtualbox
    build generic-virtualbox-x32

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
        packer build -parallel-builds=$PACKER_MAX_PROCS -except="${EXCEPTIONS}" -only="${LIST[$i]}" generic-hyperv.json
      fi
    done

    # Build the magma boxes second.
    for ((i = 0; i < ${#LIST[@]}; ++i)); do
      if [[ "${LIST[$i]}" =~ ^magma-hyperv$ ]]; then
        packer build -parallel-builds=$PACKER_MAX_PROCS -except="${EXCEPTIONS}" -only="${LIST[$i]}" magma-hyperv.json
      fi
    done
    for ((i = 0; i < ${#LIST[@]}; ++i)); do
      if [[ "${LIST[$i]}" =~ ^magma-[a-z]*[0-9]*-hyperv$ ]] && [[ "${LIST[$i]}" != ^magma-developer-hyperv$ ]]; then
        packer build -parallel-builds=$PACKER_MAX_PROCS -except="${EXCEPTIONS}" -only="${LIST[$i]}" magma-hyperv.json
      fi
    done
    for ((i = 0; i < ${#LIST[@]}; ++i)); do
      if [[ "${LIST[$i]}" =~ ^magma-developer-hyperv$ ]]; then
        packer build -parallel-builds=$PACKER_MAX_PROCS -except="${EXCEPTIONS}" -only="${LIST[$i]}" developer-hyperv.json
      fi
    done

    # Build the Lineage boxes fourth.
    for ((i = 0; i < ${#LIST[@]}; ++i)); do
      if [[ "${LIST[$i]}" =~ ^(lineage|lineageos)-hyperv$ ]]; then
        packer build -parallel-builds=$PACKER_MAX_PROCS -except="${EXCEPTIONS}" -only="${LIST[$i]}" lineage-hyperv.json
      fi
    done
    for ((i = 0; i < ${#LIST[@]}; ++i)); do
      if [[ "${LIST[$i]}" =~ ^(lineage|lineageos)-[a-z]*[0-9]*-hyperv$ ]]; then
        packer build -parallel-builds=$PACKER_MAX_PROCS -except="${EXCEPTIONS}" -only="${LIST[$i]}" lineage-hyperv.json
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

  if [[ "$(uname)" == "Darwin" ]]; then

    # Ideally, we shouldn't need this. However the ancient Macbook Air
    # used to make the Parallels boxes doesn't have the resources to
    # load the full template at once. As a workaround, the logic below
    # makes packer build the boxes, one at a time. This function also
    # removes the box file (but not the checksum) to avoid running out
    # of disk space.

    LIST=($BOXES)

    verify_json generic-parallels

    # Keep the system awake so it can finish building the boxes.
    if [ -f /usr/bin/caffeinate ]; then
      /usr/bin/caffeinate -w $$ &
    fi

    for ((i = 0; i < ${#LIST[@]}; ++i)); do
      # Ensure there is enough disk space.
      if [[ `df -m . | tail -1 |  awk -F' ' '{print $4}'` -lt 8192 ]]; then
        tput setaf 1; tput bold; printf "\n\nSkipping ${LIST[$i]} because the system is low on disk space.\n\n"; tput sgr0
      elif [[ "${LIST[$i]}" =~ ^(generic|magma)-[a-z]*[0-9]*-parallels$ ]]; then

        # Enable logging and ensure the log path exists.
        export PACKER_LOG="1"
        verify_logdir

        # Build the box. If the first attempt fails, try building the box a second time.
        if [ ! -f "$BASE/output/${LIST[$i]}-$VERSION.box" ]; then
          PACKER_LOG_PATH="$BASE/logs/generic-parallels-log-`date +'%Y%m%d.%H.%M.%S'`.txt" \
            packer build -parallel-builds=$PACKER_MAX_PROCS -except="${EXCEPTIONS}" -only="${LIST[$i]}" "$BASE/generic-parallels.json" \
            || (PACKER_LOG_PATH="$BASE/logs/generic-parallels-log-`date +'%Y%m%d.%H.%M.%S'`.txt" \
            packer build -parallel-builds=$PACKER_MAX_PROCS -except="${EXCEPTIONS}" -only="${LIST[$i]}" "$BASE/generic-parallels.json")
        fi
      fi
    done

  else
    tput setaf 1; tput bold; printf "\n\nThe Parallels robox configurations require a MacOS build machine...\n\n"; tput sgr0
  fi
}

function virtualbox() {
  verify_json generic-virtualbox
  verify_json generic-virtualbox-x32
  verify_json magma-virtualbox
  verify_json developer-virtualbox
  verify_json lineage-virtualbox

  build generic-virtualbox
  build generic-virtualbox-x32
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
elif [[ $1 == "distclean" ]]; then distclean

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
elif [[ $1 == "invalid" ]]; then invalid
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
elif [[ $1 == "generic-virtualbox-x32" || $1 == "generic-virtualbox-x32.json" ]]; then build generic-virtualbox-x32
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
  echo $"  `basename $0` {start|validate|build|cleanup|distclean} or"
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
  echo $"  `basename $0` {missing|public|invalid|available} or"
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
