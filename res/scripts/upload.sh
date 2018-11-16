#!/bin/bash

ORG="$1"
NAME="$2"
PROVIDER="$3"
VERSION="$4"
FILE="$5"

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

tput setaf 5; printf "Create the version.\n"; tput sgr0
${CURL} \
  --tlsv1.2 \
  --silent \
  --retry 16 \
  --retry-delay 60 \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer $VAGRANT_CLOUD_TOKEN" \
  "https://app.vagrantup.com/api/v1/box/$ORG/$NAME/versions" \
  --data "
    {
      \"version\": {
        \"version\": \"$VERSION\",
        \"description\": \"A build environment for use in cross platform development.\"
      }
    }
  " | jq --color-output

printf "\n\n"

tput setaf 5; printf "Delete the existing provider, if it exists already.\n"; tput sgr0
${CURL} \
  --silent \
  --retry 16 \
  --retry-delay 60 \
  --header "Authorization: Bearer $VAGRANT_CLOUD_TOKEN" \
  --request DELETE \
  https://app.vagrantup.com/api/v1/box/$ORG/$NAME/version/$VERSION/provider/${PROVIDER} | jq --color-output

printf "\n\n";

# Sleep so the deletion can propagate.
sleep 3

tput setaf 5; printf "Create the provider.\n"; tput sgr0
${CURL} \
  --tlsv1.2 \
  --silent \
  --retry 16 \
  --retry-delay 60 \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer $VAGRANT_CLOUD_TOKEN" \
  https://app.vagrantup.com/api/v1/box/$ORG/$NAME/version/$VERSION/providers \
  --data "{ \"provider\": { \"name\": \"$PROVIDER\" } }" | jq --color-output

printf "\n\n"

# ${CURL} \
#   --tlsv1.2 \
#   --silent \
#   --header "Authorization: Bearer $VAGRANT_CLOUD_TOKEN" \
#   https://app.vagrantup.com/api/v1/box/$ORG/$NAME/version/$VERSION/provider/$PROVIDER/upload

tput setaf 5; printf "Retrieve the upload path."; tput sgr0
UPLOAD_PATH=`${CURL} \
  --tlsv1.2 \
  --silent \
  --header "Authorization: Bearer $VAGRANT_CLOUD_TOKEN" \
  https://app.vagrantup.com/api/v1/box/$ORG/$NAME/version/$VERSION/provider/$PROVIDER/upload | jq -r .upload_path`

# Perform the upload, and see the bits boil.
# ${CURL} --tlsv1.2 --include --max-time 7200 --expect100-timeout 7200 --request PUT --output "$FILE.upload.log.txt" --upload-file "$FILE" "$UPLOAD_PATH"
#
# printf "\n-----------------------------------------------------\n"
# tput setaf 5
# cat "$FILE.upload.log.txt"
# tput sgr0
# printf -- "-----------------------------------------------------\n\n"

if [ "$UPLOAD_PATH" == "" ] || [ "$UPLOAD_PATH" == "null" ]; then
  printf "\n\n$FILE failed to upload...\n\n"
  exit 1
fi

printf " Done.\n\n"
# echo "$UPLOAD_PATH"

tput setaf 5; printf "Perform the box upload.\n"; tput sgr0
${CURL} --tlsv1.2 \
`# --silent ` \
`# --output "/dev/null"` \
  --show-error \
  --request PUT \
  --max-time 7200 \
  --expect100-timeout 7200 \
  --header "Connection: keep-alive" \
  --write-out "\n\nFILE: $FILE\nCODE: %{http_code}\nIP: %{remote_ip}\nBYTES: %{size_upload}\nRATE: %{speed_upload}\nSETUP TIME: %{time_starttransfer}\nTOTAL TIME: %{time_total}\n\n\n" \
  --upload-file "$FILE" "$UPLOAD_PATH"

# Give the upload time to propagate.
sleep 10

tput setaf 5; printf "Version status.\n"; tput sgr0
${CURL} \
  --silent \
  --max-time 7200 \
  --connect-timeout 7200 \
  --expect100-timeout 7200 \
  "https://app.vagrantup.com/api/v1/box/$ORG/$NAME/version/$VERSION/provider/$PROVIDER" | jq --color-output

printf "\n\n"

sleep 10

tput setaf 5; printf "Release the version.\n"; tput sgr0
${CURL} \
  --tlsv1.2 \
  --silent \
  --header "Authorization: Bearer $VAGRANT_CLOUD_TOKEN" \
  https://app.vagrantup.com/api/v1/box/$ORG/$NAME/version/$VERSION/release \
  --request PUT | jq  --color-output '.status,.version,.providers[]' | grep -vE "hosted|hosted_token|original_url|created_at|updated_at|\}|\{"

printf "\n\n"

# Revoke a Version
# ${CURL} \
#   --header "Authorization: Bearer $VAGRANT_CLOUD_TOKEN" \
#   https://app.vagrantup.com/api/v1/box/$ORG/$NAME/version/$VERSION/revoke \
#   --request PUT
