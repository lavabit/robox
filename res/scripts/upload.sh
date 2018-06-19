#!/bin/bash

ORG="roboxes"
NAME="ubuntu1804"
VERSION="1.8.10"
PROVIDER="libvirt"

# Cross Platform Script Directory
pushd `dirname $0` > /dev/null
BASE=`pwd -P`
popd > /dev/null
cd $BASE

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

# Create a Version
curl \
  --silent \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer $VAGRANT_CLOUD_TOKEN" \
  https://app.vagrantup.com/api/v1/box/$ORG/$NAME/versions \
  --data "
    {
      \"version\": {
        \"version\": \"$VERSION\",
        \"description\": \"A build environment for use in cross platform development.\"
      }
    }
  "
printf "\n\n"

# Create a Provider
curl \
  --silent \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer $VAGRANT_CLOUD_TOKEN" \
  https://app.vagrantup.com/api/v1/box/$ORG/$NAME/version/$VERSION/providers \
  --data "{ \"provider\": { \"name\": \"$PROVIDER\" } }"

printf "\n\n"

# Prepare for the Upload
RESPONSE=$(curl \
  --silent \
  --header "Authorization: Bearer $VAGRANT_CLOUD_TOKEN" \
  https://app.vagrantup.com/api/v1/box/$ORG/$NAME/version/$VERSION/provider/$PROVIDER/upload)

# Extract the upload URL from the response (requires the jq command)
UPLOAD_PATH=$(echo "$RESPONSE" | jq .upload_path)

# Perform the Upload
bash -c "curl --proto https --request PUT --insecure --upload-file $BASE/../../output/$ORG-$NAME-$PROVIDER-$VERSION.box $UPLOAD_PATH"

printf "\n\n"

# Release the Version
curl \
  --header "Authorization: Bearer $VAGRANT_CLOUD_TOKEN" \
  https://app.vagrantup.com/api/v1/box/$ORG/$NAME/version/$VERSION/release \
  --request PUT

printf "\n\n"




# Revoke a Version
# curl \
#   --header "Authorization: Bearer $VAGRANT_CLOUD_TOKEN" \
#   https://app.vagrantup.com/api/v1/box/myuser/test/version/1.2.3/revoke \
#   --request PUT

# Delete a Version
# curl \
#   --header "Authorization: Bearer $VAGRANT_CLOUD_TOKEN" \
#   --request DELETE \
#   https://app.vagrantup.com/api/v1/box/myuser/test/version/1.2.3
