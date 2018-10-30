#!/bin/bash

ORG="$1"
NAME="$2"
PROVIDER="$3"
VERSION="$4"
FILE="$5"

CURL=/opt/vagrant/embedded/bin/curl
LD_PRELOAD="/opt/vagrant/embedded/lib/libcrypto.so:/opt/vagrant/embedded/lib/libssl.so"

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
${CURL} \
  --tlsv1.2 \
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
  "
printf "\n\n"

# Delete the existing provider, if it exists already.
${CURL} \
  --header "Authorization: Bearer $VAGRANT_CLOUD_TOKEN" \
  --request DELETE \
  https://app.vagrantup.com/api/v1/box/$ORG/$NAME/version/$VERSION/provider/${PROVIDER}

printf "\n\n"

# Create the provider, while becoming one with your inner child.
${CURL} \
  --tlsv1.2 \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer $VAGRANT_CLOUD_TOKEN" \
  https://app.vagrantup.com/api/v1/box/$ORG/$NAME/version/$VERSION/providers \
  --data "{ \"provider\": { \"name\": \"$PROVIDER\" } }"

printf "\n\n"

# Prepare an upload path, and then extract that upload path from the JSON
# response using the jq command.
UPLOAD_PATH=`${CURL} \
  --tlsv1.2 \
  --silent \
  --header "Authorization: Bearer $VAGRANT_CLOUD_TOKEN" \
  https://app.vagrantup.com/api/v1/box/$ORG/$NAME/version/$VERSION/provider/$PROVIDER/upload | jq -r .upload_path`

# Perform the upload, and see the bits boil.
${CURL} --tlsv1.2 --include --max-time 7200 --expect100-timeout 7200 --request PUT --output "$FILE.upload.log.txt" --upload-file "$FILE" "$UPLOAD_PATH"

printf "\n-----------------------------------------------------\n"
tput setaf 5
cat "$FILE.upload.log.txt"
tput sgr0
printf -- "-----------------------------------------------------\n\n"

# Release the version, and watch the party rage.
${CURL} \
  --tlsv1.2 \
  --silent \
  --header "Authorization: Bearer $VAGRANT_CLOUD_TOKEN" \
  https://app.vagrantup.com/api/v1/box/$ORG/$NAME/version/$VERSION/release \
  --request PUT | jq '.status,.version,.providers[]' | grep -vE "hosted|hosted_token|original_url|created_at|updated_at|\}|\{"

printf "\n\n"




# Revoke a Version
# ${CURL} \
#   --header "Authorization: Bearer $VAGRANT_CLOUD_TOKEN" \
#   https://app.vagrantup.com/api/v1/box/$ORG/$NAME/version/$VERSION/revoke \
#   --request PUT
