#!/bin/bash

# On MacOS the following utilities are needed.
# brew install --with-default-names jq gnu-sed coreutils
# BOXES=(`find output -type f -name "*.box"`)
# parallel -j 4 --xapply res/scripts/silent.sh {1} ::: "${BOXES[@]}"

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

if [ $# != 1 ]; then
  tput setaf 1; printf "\n\n  Usage:\n    $0 FILENAME\n\n\n"; tput sgr0
  exit 1
fi

if [ ! -f "$1" ]; then
  tput setaf 1; printf "\n\nThe $1 file does not exist.\n\n\n"; tput sgr0
  exit 1
fi

if [ -f /opt/vagrant/embedded/bin/curl ]; then
  export CURL="/opt/vagrant/embedded/bin/curl"
else
  export CURL="curl"
fi

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

if [[ `uname` == "Darwin" ]]; then
  export CURL_CA_BUNDLE=/opt/vagrant/embedded/cacert.pem
fi

# The jq tool is needed to parse JSON responses.
if [ ! -f /usr/bin/sha256sum ]; then
  tput setaf 1; printf "\n\nThe 'sha256sum' utility is not installed.\n\n\n"; tput sgr0
  exit 1
fi

AGENT="Vagrant/2.2.9 (+https://www.vagrantup.com; ruby2.6.6)"

FILENAME=`basename "$1"`
FILEPATH=`realpath "$1"`

(echo "$FILENAME" | grep --silent -E "\.sha256\$") || (tput setaf 1; printf "\n\nThe file does not have a proper extension.\n\n\n";  tput sgr0; exit 1)

ORG=`echo "$FILENAME" | sed "s/\([a-z]*\)[\-]*\([a-z0-9-]*\)-\(hyperv\|vmware\|libvirt\|docker\|parallels\|virtualbox\)-\([0-9\.]*\).box.sha256/\1/g"`
BOX=`echo "$FILENAME" | sed "s/\([a-z]*\)[-]*\([a-z0-9-]*\)-\(hyperv\|vmware\|libvirt\|docker\|parallels\|virtualbox\)-\([0-9\.]*\).box.sha256/\2/g"`
PROVIDER=`echo "$FILENAME" | sed "s/\([a-z]*\)[-]*\([a-z0-9-]*\)-\(hyperv\|vmware\|libvirt\|docker\|parallels\|virtualbox\)-\([0-9\.]*\).box.sha256/\3/g"`
VERSION=`echo "$FILENAME" | sed "s/\([a-z]*\)[-]*\([a-z0-9-]*\)-\(hyperv\|vmware\|libvirt\|docker\|parallels\|virtualbox\)-\([0-9\.]*\).box.sha256/\4/g"`

# Handle the Lavabit boxes.
if [ "$ORG" == "magma" ]; then
  ORG="lavabit"
  if [ "$BOX" == "" ]; then
    BOX="magma"
  else
    BOX="magma-$BOX"
  fi

  # Specialized magma box name mappings.
  [ "$BOX" == "magma-alpine36" ] && BOX="magma-alpine"
  [ "$BOX" == "magma-debian8" ] && BOX="magma-debian"
  [ "$BOX" == "magma-fedora27" ] && BOX="magma-fedora"
  [ "$BOX" == "magma-freebsd11" ] && BOX="magma-freebsd"
  [ "$BOX" == "magma-openbsd6" ] && BOX="magma-openbsd"

fi

# Handle the Lineage boxes.
if [ "$ORG" == "lineage" ] || [ "$ORG" == "lineageos" ]; then
  if [ "$BOX" == "" ]; then
    BOX="lineage"
  else
    BOX="lineage-$BOX"
  fi
fi

# Handle the Vmware provider type.
if [ "$PROVIDER" == "vmware" ]; then
  PROVIDER="vmware_desktop"
fi

# Read the hash in from the checksum file.
HASH="`awk -F' ' '{print $1}' $FILEPATH`"

# Verify the values were all parsed properly.
if [ "$ORG" == "" ]; then
  tput setaf 1; printf "\n\nThe organization couldn't be parsed from the file name.\n\n\n"; tput sgr0
  exit 1
fi

if [ "$BOX" == "" ]; then
  tput setaf 1; printf "\n\nThe box name couldn't be parsed from the file name.\n\n\n"; tput sgr0
  exit 1
fi

if [ "$PROVIDER" == "" ]; then
  tput setaf 1; printf "\n\nThe provider couldn't be parsed from the file name.\n\n\n"; tput sgr0
  exit 1
fi

if [ "$VERSION" == "" ]; then
  tput setaf 1; printf "\n\nThe version couldn't be parsed from the file name.\n\n\n"; tput sgr0
  exit 1
fi

if [ "$HASH" == "" ]; then
  tput setaf 1; printf "\n\nThe SHA 256 hash couldn't be parsed from the input file.\n\n\n"; tput sgr0
  exit 1
fi

if [ `echo "$HASH" | wc -c` != 65 ]; then
  tput setaf 1; printf "\n\nThe SHA 256 hash couldn't be parsed from the input file.\n\n\n"; tput sgr0
  exit 1
fi

# Private magma boxes can't be verified. so we skip them.
if [ "$BOX" == "magma-alpine" ] || [ "$BOX" == "magma-arch" ] || [ "$BOX" == "magma-freebsd" ] || [ "$BOX" == "magma-gentoo" ] || [ "$BOX" == "magma-openbsd" ]; then
  printf "Box  ~  " ; tput setaf 3 ; printf "${ORG}/${BOX} ${PROVIDER} ${VERSION}\n" ; tput sgr0
  exit 0
fi

# org name provider version hash
function download() {

  HASH=`curl --silent --location --retry 10 --retry-delay 120 --max-redirs 10 --user-agent "${AGENT}" https://vagrantcloud.com/$1/boxes/$2/versions/$4/providers/$3.box | sha256sum`

  echo "$HASH" | grep --silent "$5"

  # The grep return code tells us whether it found a match in the header or not.
  if [ $? != 0 ]; then

    # Retry failed downloads, just in case the error was ephemeral.
    HASH=`curl --silent --location --retry 10 --retry-delay 120 --max-redirs 10 --user-agent "${AGENT}" https://vagrantcloud.com/$1/boxes/$2/versions/$4/providers/$3.box | sha256sum`

    echo "$HASH" | grep --silent "$5"

    if [ $? != 0 ]; then
      printf "Box  -  "; tput setaf 1; printf "${ORG}/${BOX} ${PROVIDER} ${VERSION}\n"; tput sgr0
    else
      printf "Box  +  "; tput setaf 2; printf "${ORG}/${BOX} ${PROVIDER} ${VERSION}\n"; tput sgr0
    fi

  else
    printf "Box  +  "; tput setaf 2; printf "${ORG}/${BOX} ${PROVIDER} ${VERSION}\n"; tput sgr0
  fi

  return 0
}

download $ORG $BOX $PROVIDER $VERSION $HASH
