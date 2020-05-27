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

if [ $# != 4 ]; then
  tput setaf 1; printf "\n\n  Usage:\n    $0 ORG BOX PROVIDER VERSION\n\n\n"; tput sgr0
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

ORG="$1"
BOX="$2"
PROVIDER="$3"
VERSION="$4"

# Handle the Vmware provider type.
if [ "$PROVIDER" == "vmware" ]; then
  PROVIDER="vmware_desktop"
fi

# Verify the values were all parsed properly.
if [ "$ORG" == "" ]; then
  tput setaf 1; printf "\n\nThe organization couldn't be parsed correctly.\n\n\n"; tput sgr0
  exit 1
fi

if [ "$BOX" == "" ]; then
  tput setaf 1; printf "\n\nThe box name couldn't be parsed correctly.\n\n\n"; tput sgr0
  exit 1
fi

if [ "$PROVIDER" == "" ]; then
  tput setaf 1; printf "\n\nThe provider couldn't be parsed correctly.\n\n\n"; tput sgr0
  exit 1
fi

if [ "$VERSION" == "" ]; then
  tput setaf 1; printf "\n\nThe version couldn't be parsed correctly.\n\n\n"; tput sgr0
  exit 1
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

COUNT=1
DELAY=1
RESULT=0

while [[ "${COUNT}" -le 100 ]]; do
  RESULT=0
  DATA=`curl --fail --silent --location --retry 10 --retry-delay 120 --max-redirs 10 --user-agent "${AGENT}" https://app.vagrantup.com/api/v1/box/$ORG/$BOX/version/$VERSION`
  # CHECKSUM=`curl --fail --silent --location --retry 10 --retry-delay 120 --max-redirs 10 --user-agent "${AGENT}" https://app.vagrantup.com/api/v1/box/$1/$2/version/$4 | jq -e -r ".providers[] | select( .name | contains(\"$3\")) | .checksum"`
  RESULT="${?}"
  if [[ $RESULT == 0 ]]; then
    break
  fi
  COUNT="$((COUNT + 1))"
  DELAY="$((DELAY + 1))"
  sleep $DELAY
done

HASH=`echo $DATA | jq -e -r ".providers[] | select( .name | contains(\"$PROVIDER\")) | .checksum"`

if [ "$HASH" == "" ]; then
  tput setaf 1; printf "\n\nThe SHA 256 hash couldn't be retrieved from the server.\n\n\n"; tput sgr0
  exit 1
fi

if [ `echo "$HASH" | wc -c` != 65 ]; then
  tput setaf 1; printf "\n\nThe SHA 256 hash retrieved from the server isn't the correct length.\n\n\n"; tput sgr0
  exit 1
fi

download $ORG $BOX $PROVIDER $VERSION $HASH
