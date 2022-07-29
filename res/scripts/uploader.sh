#!/bin/bash

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

if [ $# != 5 ]; then
  tput setaf 1; printf "\n\n  Usage:\n    $0 ORG BOX PROVIDER VERSION FILENAME\n\n\n"; tput sgr0
  exit 1
fi

if [ ! -f "$5" ]; then
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
if [ ! -f /usr/bin/jq ] && [ ! -f /usr/local/bin/jq ]; then
  tput setaf 1; printf "\n\nThe 'jq' utility is not installed.\n\n\n"; tput sgr0
  exit 1
fi

# Ensure the credentials file is available.
if [ -f $BASE/../../.credentialsrc ]; then
  source $BASE/../../.credentialsrc
fi

if [ -z ${VAGRANT_CLOUD_TOKEN} ]; then
  tput setaf 1; printf "\nError. The vagrant cloud token is missing. Add it to the credentials file.\n\n"; tput sgr0
  exit 2
fi

FILENAME=`basename "$5"`
FILEPATH=`realpath "$5"`

ORG="$1"
BOX="$2"
PROVIDER="$3"
VERSION="$4"

# Handle the Vmware provider type.
if [ "$PROVIDER" == "vmware" ]; then
  PROVIDER="vmware_desktop"
fi

# Generate the hash using the box file.
HASH="`sha256sum $FILEPATH | awk -F' ' '{print $1}'`"

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

# Generate a hash using the box file if value is invalid.
if [ "$HASH" == "" ] || [ `echo "$HASH" | wc -c` != 65 ]; then
  HASH="`sha256sum $FILEPATH | awk -F' ' '{print $1}'`"
fi

# If the hash is still invalid, then we report an error and exit.
if [ `echo "$HASH" | wc -c` != 65 ]; then
  tput setaf 1; printf "\n\nThe hash couldn't be calculated properly.\n\n\n"; tput sgr0
  exit 1
fi

retry() {
  local COUNT=1
  local RESULT=0
  while [[ "${COUNT}" -le 10 ]]; do
    [[ "${RESULT}" -ne 0 ]] && {
      echo ""
      printf "  %s ${T_BYEL}failed.${T_RESET}... retrying ${COUNT} of 10.\n" "${*}" >&2
      echo ""
    }
    "${@}" && { RESULT=0 && break; } || RESULT="${?}"
    COUNT="$((COUNT + 1))"

    # Increase the delay with each iteration.
    DELAY="$((DELAY + 10))"
    sleep $DELAY
  done

  [[ "${COUNT}" -gt 10 ]] && {
    echo -e "\\n$(tput setaf 1)The command failed 10 times.$(tput sgr0)\\n" >&2
  }

  return "${RESULT}"
}

printf "\n\n"

tput setaf 5; printf "Create the version.\n"; tput sgr0
(${CURL} \
  --tlsv1.2 \
  --silent \
  --retry 16 \
  --retry-delay 60 \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer $VAGRANT_CLOUD_TOKEN" \
  "https://app.vagrantup.com/api/v1/box/$ORG/$BOX/versions" \
  --data "
    {
      \"version\": {
        \"version\": \"$VERSION\",
        \"description\": \"A build environment for use in cross platform development.\"
      }
    }
  " | jq --color-output 2>/dev/null) || (tput setaf 1; printf "Version creation failed. { $ORG $BOX $PROVIDER $VERSION }\n"; tput sgr0; exit)

printf "\n\n"

tput setaf 5; printf "Delete the existing provider, if it exists already.\n"; tput sgr0
(${CURL} \
  --silent \
  --retry 16 \
  --retry-delay 60 \
  --header "Authorization: Bearer $VAGRANT_CLOUD_TOKEN" \
  --request DELETE \
  https://app.vagrantup.com/api/v1/box/$ORG/$BOX/version/$VERSION/provider/${PROVIDER} \
  | jq --color-output 2>/dev/null) || (tput setaf 1; printf "Unable to delete an existing version of the box. { $ORG $BOX $PROVIDER $VERSION }\n"; tput sgr0)

printf "\n\n";

# Sleep in case the deletion needs to propagate.
sleep 3

tput setaf 5; printf "Create the provider.\n"; tput sgr0
(${CURL} \
  --tlsv1.2 \
  --silent \
  --retry 16 \
  --retry-delay 60 \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer $VAGRANT_CLOUD_TOKEN" \
  https://app.vagrantup.com/api/v1/box/$ORG/$BOX/version/$VERSION/providers \
  --data "{ \"provider\": { \"name\": \"$PROVIDER\", \"checksum\": \"$HASH\", \"checksum_type\": \"SHA256\" } }" \
  | jq --color-output) || (tput setaf 1; printf "Unable to create the box provider. { $ORG $BOX $PROVIDER $VERSION }\n"; tput sgr0; exit)

printf "\n\n"

tput setaf 5; printf "Retrieve the upload path."; tput sgr0
UPLOAD_PATH=`${CURL} \
  --tlsv1.2 \
  --silent \
  --header "Authorization: Bearer $VAGRANT_CLOUD_TOKEN" \
  https://app.vagrantup.com/api/v1/box/$ORG/$BOX/version/$VERSION/provider/$PROVIDER/upload | jq -r .upload_path`

if [ "$UPLOAD_PATH" == "" ] || [ "$UPLOAD_PATH" == "null" ]; then
  printf "\n\n$FILENAME failed to upload...\n\n"
  exit 1
fi

printf " Done.\n\n"

# Perform the upload, and see the bits fly.
tput setaf 5; printf "Perform the box upload.\n"; tput sgr0
retry ${CURL} --tlsv1.2 \
  --output '/dev/null' \
  --show-error \
  --request PUT \
  --max-time 7200 \
  --expect100-timeout 7200 \
  --header "Connection: keep-alive" \
  --upload-file "$FILEPATH" "$UPLOAD_PATH"

# Give the upload time to propagate.
sleep 5

tput setaf 5; printf "Version status.\n"; tput sgr0
${CURL} \
  --silent \
  --max-time 7200 \
  --connect-timeout 7200 \
  --expect100-timeout 7200 \
  "https://app.vagrantup.com/api/v1/box/$ORG/$BOX/version/$VERSION/provider/$PROVIDER" | jq --color-output

printf "\n\n"

sleep 5

# Check the version status to ensure it was released properly.
tput setaf 5; printf "Release the version.\n"; tput sgr0
${CURL} \
  --tlsv1.2 \
  --silent \
  --header "Authorization: Bearer $VAGRANT_CLOUD_TOKEN" \
  https://app.vagrantup.com/api/v1/box/$ORG/$BOX/version/$VERSION/release \
  --request PUT | jq  --color-output '.status,.version,.providers[]' | grep -vE "hosted|hosted_token|original_url|created_at|updated_at|\}|\{"

printf "\n\n"
