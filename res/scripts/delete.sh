#!/bin/bash

# Handle self referencing, sourcing etc.
if [[ $0 != "${BASH_SOURCE[0]}" ]]; then
  export CMD="${BASH_SOURCE[0]}"
else
  export CMD=$0
fi

# Ensure a consistent working directory so relative paths work.
pushd "$(dirname "$CMD")" > /dev/null
BASE=$(pwd -P)
popd > /dev/null

if [ $# != 3 ] && [ $# != 5 ]; then
  printf "  Delete an entire box version.\n  Usage:  $0 ORG BOX VERSION\n\n"
  printf "  Delete a specific box provider.\n  Usage:  $0 ORG BOX PROVIDER ARCH VERSION\n\n"
  exit 1
fi

if [ $# == 3 ]; then
ORG="$1"
BOX="$2"
VERSION="$3"
elif [ $# == 5 ]; then
ORG="$1"
BOX="$2"
PROVIDER="$3"
ARCH="$4"
VERSION="$5"
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

# The jq tool is needed to parse JSON responses.
if [ ! -f /usr/bin/jq ]; then
  tput setaf 1; printf "\n\nThe 'jq' utility is not installed.\n\n\n"; tput sgr0
  exit 1
fi

# Ensure the credentials file is available.
if [ -f $BASE/../../.credentialsrc ]; then
  source $BASE/../../.credentialsrc
else
  tput setaf 1; printf "\nError. The credentials file is missing.\n\n"; tput sgr0
  exit 2
fi

if [ -z ${VAGRANT_CLOUD_TOKEN} ]; then
  tput setaf 1; printf "\nError. The vagrant cloud token is missing. Add it to the credentials file.\n\n"; tput sgr0
  exit 2
fi

printf "\n"

if [ $# == 5 ]; then
  ${CURL} --tlsv1.2 --silent --retry 4 --retry-delay 2 --max-time 180 --request DELETE --fail \
  --header "Authorization: Bearer $VAGRANT_CLOUD_TOKEN" \
  "https://app.vagrantup.com/api/v2/box/$ORG/$BOX/version/$VERSION/provider/${PROVIDER}/${ARCH}"
else
  ${CURL} --tlsv1.2 --silent --retry 4 --retry-delay 2 --max-time 180 --request DELETE --fail \
  --header "Authorization: Bearer $VAGRANT_CLOUD_TOKEN" \
  "https://app.vagrantup.com/api/v2/box/$ORG/$BOX/version/$VERSION"
fi

printf "\n"
