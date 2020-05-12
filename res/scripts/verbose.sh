#!/bin/bash

# On MacOS the following utilities are needed.
# brew install --with-default-names jq gnu-sed coreutils
# BOXES=(`find output -type f -name "*.box"`)
# parallel -j 4 --xapply res/scripts/upload.sh {1} ::: "${BOXES[@]}"

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
if [ ! -f /usr/bin/jq ] && [ ! -f /usr/local/bin/jq ]; then
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

FILENAME=`basename "$1"`
FILEPATH=`realpath "$1"`

ORG=`echo "$FILENAME" | sed "s/\([a-z]*\)[\-]*\([a-z0-9-]*\)-\(hyperv\|vmware\|libvirt\|docker\|parallels\|virtualbox\)-\([0-9\.]*\).box/\1/g"`
BOX=`echo "$FILENAME" | sed "s/\([a-z]*\)[-]*\([a-z0-9-]*\)-\(hyperv\|vmware\|libvirt\|docker\|parallels\|virtualbox\)-\([0-9\.]*\).box/\2/g"`
PROVIDER=`echo "$FILENAME" | sed "s/\([a-z]*\)[-]*\([a-z0-9-]*\)-\(hyperv\|vmware\|libvirt\|docker\|parallels\|virtualbox\)-\([0-9\.]*\).box/\3/g"`
VERSION=`echo "$FILENAME" | sed "s/\([a-z]*\)[-]*\([a-z0-9-]*\)-\(hyperv\|vmware\|libvirt\|docker\|parallels\|virtualbox\)-\([0-9\.]*\).box/\4/g"`

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

# Modify the org/box for 32 bit variants.
if [[ "$BOX" =~ ^.*-x32$ ]]; then
  ORG="${ORG}-x32"
  BOX="`echo $BOX | sed s/-x32//g`"
fi

# Find the box checksum.
if [ -f $FILEPATH.sha256 ]; then

  # Read the hash in from the checksum file.
  HASH="`awk -F' ' '{print $1}' $FILEPATH.sha256`"

else

  # Generate the hash using the box file.
  HASH="`sha256sum $FILEPATH | awk -F' ' '{print $1}'`"

fi

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
  tput setaf 1; printf "\n\nThe hash couldn't be calculated properly.\n\n\n"; tput sgr0
  exit 1
fi

retry() {
  local COUNT=1
  local RESULT=0
  while [[ "${COUNT}" -le 10 ]]; do
    [[ "${RESULT}" -ne 0 ]] && {
      echo ""
      echo -e "$(tput setaf 1)${*} failed... retrying ${COUNT} of 10.$(tput sgr0)" | tr -d \\n >&2
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

# Sleep to let the deletion propagate.
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

# ${CURL} \
#   --tlsv1.2 \
#   --silent \
#   --header "Authorization: Bearer $VAGRANT_CLOUD_TOKEN" \
#   https://app.vagrantup.com/api/v1/box/$ORG/$BOX/version/$VERSION/provider/$PROVIDER/upload

tput setaf 5; printf "Retrieve the upload path."; tput sgr0
UPLOAD_PATH=`${CURL} \
  --tlsv1.2 \
  --silent \
  --header "Authorization: Bearer $VAGRANT_CLOUD_TOKEN" \
  https://app.vagrantup.com/api/v1/box/$ORG/$BOX/version/$VERSION/provider/$PROVIDER/upload | jq -r .upload_path`

# Perform the upload, and see the bits boil.
# ${CURL} --tlsv1.2 --include --max-time 7200 --expect100-timeout 7200 --request PUT --output "$FILEPATH.upload.log.txt" --upload-file "$FILEPATH" "$UPLOAD_PATH"
#
# printf "\n-----------------------------------------------------\n"
# tput setaf 5
# cat "$FILEPATH.upload.log.txt"
# tput sgr0
# printf -- "-----------------------------------------------------\n\n"

if [ "$UPLOAD_PATH" == "" ] || [ "$UPLOAD_PATH" == "null" ]; then
  printf "\n\n$FILENAME failed to upload...\n\n"
  exit 1
fi

printf " Done.\n\n"
# echo "$UPLOAD_PATH"

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

# sleep 10
#
# tput setaf 5; printf "Release the version.\n"; tput sgr0
# ${CURL} \
#   --tlsv1.2 \
#   --silent \
#   --header "Authorization: Bearer $VAGRANT_CLOUD_TOKEN" \
#   https://app.vagrantup.com/api/v1/box/$ORG/$BOX/version/$VERSION/release \
#   --request PUT | jq  --color-output '.status,.version,.providers[]' | grep -vE "hosted|hosted_token|original_url|created_at|updated_at|\}|\{"
#
# printf "\n\n"

# Revoke a Version
# ${CURL} \
#   --header "Authorization: Bearer $VAGRANT_CLOUD_TOKEN" \
#   https://app.vagrantup.com/api/v1/box/$ORG/$BOX/version/$VERSION/revoke \
#   --request PUT
