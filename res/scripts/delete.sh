#!/bin/bash

ORG="$1"
NAME="$2"
PROVIDER="$3"
VERSION="$4"

CURL=/opt/vagrant/embedded/bin/curl
export LD_PRELOAD="/opt/vagrant/embedded/lib64/libcrypto.so:/opt/vagrant/embedded/lib64/libssl.so"
export LD_LIBRARY_PATH="/opt/vagrant/embedded/bin/lib/:/opt/vagrant/embedded/lib64/"

# Cross platform scripting directory plus munchie madness.
pushd `dirname $0` > /dev/null
BASE=`pwd -P`
popd > /dev/null

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

printf "\n\n"

# Assume the position, while you create the version.
#${CURL} \
#  --tlsv1.2 \
#  --silent \
#  --retry 16 \
#  --retry-delay 60 \
#  --header "Content-Type: application/json" \
#  --header "Authorization: Bearer $VAGRANT_CLOUD_TOKEN" \
#  "https://app.vagrantup.com/api/v1/box/$ORG/$NAME/versions" \
#  --data "
#    {
#      \"version\": {
#        \"version\": \"$VERSION\",
#        \"description\": \"A build environment for use in cross platform development.\"
#      }
#    }
#  "
#printf "\n\n"

# Delete the existing provider, if it exists already.
${CURL} \
  --silent \
  --retry 16 \
  --retry-delay 60 \
  --header "Authorization: Bearer $VAGRANT_CLOUD_TOKEN" \
  --request DELETE \
  https://app.vagrantup.com/api/v1/box/$ORG/$NAME/version/$VERSION/provider/$PROVIDER

printf "\n\n"
