#!/bin/bash -eu

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
cd $BASE/../../

if [ $# != 4 ]; then
  tput setaf 1; printf "\n   $0 SOURCE TARGET ISO SHA\n\n Please specify the source, target, install media, and hash.\n\n"; tput sgr0
  exit 1
fi

# Verify the files exist.
if [ ! -f magma-hyperv.json ]; then
  tput setaf 1; printf "\n magma-hyperv.json file is missing.\n\n"; tput sgr0
  exit 1
elif [ ! -f magma-vmware.json ]; then
  tput setaf 1; printf "\n magma-vmware.json file is missing.\n\n"; tput sgr0
  exit 1
elif [ ! -f magma-libvirt.json ]; then
  tput setaf 1; printf "\n magma-libvirt.json file is missing.\n\n"; tput sgr0
  exit 1
elif [ ! -f magma-virtualbox.json ]; then
  tput setaf 1; printf "\n magma-virtualbox.json file is missing.\n\n"; tput sgr0
  exit 1
fi

# Ensure we aren't overwriting unsaved changes.
if [ `git status --short magma-hyperv.json | wc --lines` != 0 ]; then
  tput setaf 1; printf "\n magma-hyperv.json file has uncommitted changes.\n\n"; tput sgr0
  exit 1
elif [ `git status --short magma-vmware.json | wc --lines` != 0 ]; then
  tput setaf 1; printf "\n magma-vmware.json file has uncommitted changes.\n\n"; tput sgr0
  exit 1
elif [ `git status --short magma-libvirt.json | wc --lines` != 0 ]; then
  tput setaf 1; printf "\n magma-libvirt.json file has uncommitted changes.\n\n"; tput sgr0
  exit 1
elif [ `git status --short magma-virtualbox.json | wc --lines` != 0 ]; then
  tput setaf 1; printf "\n magma-virtualbox.json file has uncommitted changes.\n\n"; tput sgr0
  exit 1
fi

URL=`printf "$3" | sed "s/\//\\\\\\\\\//g"`

# Add  the builder config along with the provisioners. 
BUILDERS=`jq "[ .builders[] | select( .name | contains(\"$1\")) ]" magma-hyperv.json | \
  sed "s/$1/$2/g" | sed "s/\"iso_url\": \".*\",/\"iso_url\": \"$URL\",/g" | sed "s/\"iso_checksum\": \".*\",/\"iso_checksum\": \"sha256:$4\",/g" | sed "s/$( echo $1 | sed 's/magma-//g')/$( echo $2 | sed 's/magma-//g')/g"`
PROVISIONERS=`jq "[ .provisioners[] | select( .only[0] // \"no\" | contains(\"$1\")) ]" magma-hyperv.json | sed "s/$( echo $1 | sed 's/magma-//g')/$( echo $2 | sed 's/magma-//g')/g"`
jq --argjson new1 "${PROVISIONERS}" --argjson new2 "${BUILDERS}" '.provisioners |= .[:-1] + $new1 + .[-1:] | .builders += $new2' magma-hyperv.json > magma-hyperv.new.json
 
BUILDERS=`jq "[ .builders[] | select( .name | contains(\"$1\")) ]" magma-vmware.json | \
  sed "s/$1/$2/g" | sed "s/\"iso_url\": \".*\",/\"iso_url\": \"$URL\",/g" | sed "s/\"iso_checksum\": \".*\",/\"iso_checksum\": \"sha256:$4\",/g" | sed "s/$( echo $1 | sed 's/magma-//g')/$( echo $2 | sed 's/magma-//g')/g"`
PROVISIONERS=`jq "[ .provisioners[] | select( .only[0] // \"no\" | contains(\"$1\")) ]" magma-vmware.json | sed "s/$( echo $1 | sed 's/magma-//g')/$( echo $2 | sed 's/magma-//g')/g"`
jq --argjson new1 "${PROVISIONERS}" --argjson new2 "${BUILDERS}" '.provisioners |= .[:-1] + $new1 + .[-1:] | .builders += $new2' magma-vmware.json > magma-vmware.new.json

BUILDERS=`jq "[ .builders[] | select( .name | contains(\"$1\")) ]" magma-libvirt.json | \
  sed "s/$1/$2/g" | sed "s/\"iso_url\": \".*\",/\"iso_url\": \"$URL\",/g" | sed "s/\"iso_checksum\": \".*\",/\"iso_checksum\": \"sha256:$4\",/g" | sed "s/$( echo $1 | sed 's/magma-//g')/$( echo $2 | sed 's/magma-//g')/g"`
PROVISIONERS=`jq "[ .provisioners[] | select( .only[0] // \"no\" | contains(\"$1\")) ]" magma-libvirt.json | sed "s/$( echo $1 | sed 's/magma-//g')/$( echo $2 | sed 's/magma-//g')/g"`
jq --argjson new1 "${PROVISIONERS}" --argjson new2 "${BUILDERS}" '.provisioners |= .[:-1] + $new1 + .[-1:] | .builders += $new2' magma-libvirt.json > magma-libvirt.new.json

BUILDERS=`jq "[ .builders[] | select( .name | contains(\"$1\")) ]" magma-virtualbox.json | \
  sed "s/$1/$2/g" | sed "s/\"iso_url\": \".*\",/\"iso_url\": \"$URL\",/g" | sed "s/\"iso_checksum\": \".*\",/\"iso_checksum\": \"sha256:$4\",/g" | sed "s/$( echo $1 | sed 's/magma-//g')/$( echo $2 | sed 's/magma-//g')/g"`
PROVISIONERS=`jq "[ .provisioners[] | select( .only[0] // \"no\" | contains(\"$1\")) ]" magma-virtualbox.json | sed "s/$( echo $1 | sed 's/magma-//g')/$( echo $2 | sed 's/magma-//g')/g"`
jq --argjson new1 "${PROVISIONERS}" --argjson new2 "${BUILDERS}" '.provisioners |= .[:-1] + $new1 + .[-1:] | .builders += $new2' magma-virtualbox.json > magma-virtualbox.new.json

# Duplicate the auto-install configs/scripts.
rename "http/$( echo $1 | sed 's/-/\./g')" "http/$( echo $2 | sed 's/-/\./g')" http/$( echo $1 | sed 's/-/\./g')* && git checkout -- "http/$( echo $1 | sed 's/-/\./g')*"

# Replace the box name inside scripts (if applicable).
find "http/" -name "$( echo $2 | sed 's/-/\./g')*" -type f -exec sed --in-place "s/$1/$2/g" {} \;

# Credentials and tokens.
if [ ! -f .credentialsrc ]; then
tput setaf 1; printf "\n\nThe credentials file is missing, so the validation is being skipped.\n\n\n"; tput sgr0
else

  # Import the credentials.
  source .credentialsrc

  # We need to specify a version, but since we aren't building at this point, any value should work.
  export VERSION="1.0.0"

  # We only validate these files, two at a time, because the packer validation process spwans 350+ processes.
  packer validate magma-hyperv.new.json &> /dev/null || exit 1
  packer validate magma-vmware.new.json &> /dev/null || exit 1
  packer validate magma-libvirt.new.json &> /dev/null || exit 1
  packer validate magma-virtualbox.new.json &> /dev/null || exit 1

fi

mv magma-hyperv.new.json magma-hyperv.json
mv magma-vmware.new.json magma-vmware.json
mv magma-libvirt.new.json magma-libvirt.json
mv magma-virtualbox.new.json magma-virtualbox.json
