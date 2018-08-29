#!/bin/bash -eu

ORG="$1"
NAME="$2"
VERSION="$3"

CURL=/opt/vagrant/embedded/bin/curl
LD_PRELOAD="/opt/vagrant/embedded/lib/libcrypto.so:/opt/vagrant/embedded/lib/libssl.so"

# Cross Platform Script Directory
pushd `dirname $0` > /dev/null
BASE=`pwd -P`
popd > /dev/null

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

printf "\n\n"

${CURL} \
  --header "Authorization: Bearer $VAGRANT_CLOUD_TOKEN" \
  --request DELETE \
  https://app.vagrantup.com/api/v1/box/$ORG/$NAME/version/$VERSION
