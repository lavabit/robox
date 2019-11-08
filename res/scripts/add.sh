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
if [ ! -f packer-cache.json ]; then
  tput setaf 1; printf "\n packer-cache.json file is missing.\n\n"; tput sgr0
  exit 1
elif [ ! -f generic-hyperv.json ]; then
  tput setaf 1; printf "\n generic-hyperv.json file is missing.\n\n"; tput sgr0
  exit 1
elif [ ! -f generic-vmware.json ]; then
  tput setaf 1; printf "\n generic-vmware.json file is missing.\n\n"; tput sgr0
  exit 1
elif [ ! -f generic-libvirt.json ]; then
  tput setaf 1; printf "\n generic-libvirt.json file is missing.\n\n"; tput sgr0
  exit 1
elif [ ! -f generic-parallels.json ]; then
  tput setaf 1; printf "\n generic-parallels.json file is missing.\n\n"; tput sgr0
  exit 1
elif [ ! -f generic-virtualbox.json ]; then
  tput setaf 1; printf "\n generic-virtualbox.json file is missing.\n\n"; tput sgr0
  exit 1
fi

# Ensure we aren't overwriting unsaved changes.
if [ `git status --short packer-cache.json | wc --lines` != 0 ]; then
  tput setaf 1; printf "\n packer-cache.json file has uncommitted changes.\n\n"; tput sgr0
  exit 1
elif [ `git status --short generic-hyperv.json | wc --lines` != 0 ]; then
  tput setaf 1; printf "\n generic-hyperv.json file has uncommitted changes.\n\n"; tput sgr0
  exit 1
elif [ `git status --short generic-vmware.json | wc --lines` != 0 ]; then
  tput setaf 1; printf "\n generic-vmware.json file has uncommitted changes.\n\n"; tput sgr0
  exit 1
elif [ `git status --short generic-libvirt.json | wc --lines` != 0 ]; then
  tput setaf 1; printf "\n generic-libvirt.json file has uncommitted changes.\n\n"; tput sgr0
  exit 1
elif [ `git status --short generic-parallels.json | wc --lines` != 0 ]; then
  tput setaf 1; printf "\n generic-parallels.json file has uncommitted changes.\n\n"; tput sgr0
  exit 1
elif [ `git status --short generic-virtualbox.json | wc --lines` != 0 ]; then
  tput setaf 1; printf "\n generic-virtualbox.json file has uncommitted changes.\n\n"; tput sgr0
  exit 1
fi

URL=`printf "$3" | sed "s/\//\\\\\\\\\//g"`

# Add a cached config.
BUILDERS=`jq "[ .builders[] | select( .name | contains(\"$1\")) ]" packer-cache.json | \
  sed "s/$1/$2/g" | sed "s/\"iso_url\": \".*\",/\"iso_url\": \"$URL\",/g" | sed "s/\"iso_checksum\": \".*\",/\"iso_checksum\": \"$4\",/g"`
jq --argjson new1 "${BUILDERS}" '.builders |= .[:-1] + $new1 + .[-1:]' packer-cache.json > packer-cache.new.json

# Add provisioner/builder configs.
BUILDERS=`jq "[ .builders[] | select( .name | contains(\"$1\")) ]" generic-hyperv.json | \
  sed "s/$1/$2/g" | sed "s/\"iso_url\": \".*\",/\"iso_url\": \"$URL\",/g" | sed "s/\"iso_checksum\": \".*\",/\"iso_checksum\": \"$4\",/g"`
PROVISIONERS=`jq "[ .provisioners[] | select( .only[0] // \"no\" | contains(\"$1\")) ]" generic-hyperv.json | sed "s/$1/$2/g"`
jq --argjson new1 "${PROVISIONERS}" --argjson new2 "${BUILDERS}" '.provisioners |= .[:-1] + $new1 + .[-1:] | .builders += $new2' generic-hyperv.json > generic-hyperv.new.json

BUILDERS=`jq "[ .builders[] | select( .name | contains(\"$1\")) ]" generic-vmware.json | \
  sed "s/$1/$2/g" | sed "s/\"iso_url\": \".*\",/\"iso_url\": \"$URL\",/g" | sed "s/\"iso_checksum\": \".*\",/\"iso_checksum\": \"$4\",/g"`
PROVISIONERS=`jq "[ .provisioners[] | select( .only[0] // \"no\" | contains(\"$1\")) ]" generic-vmware.json | sed "s/$1/$2/g"`
jq --argjson new1 "${PROVISIONERS}" --argjson new2 "${BUILDERS}" '.provisioners |= .[:-1] + $new1 + .[-1:] | .builders += $new2' generic-vmware.json > generic-vmware.new.json

BUILDERS=`jq "[ .builders[] | select( .name | contains(\"$1\")) ]" generic-libvirt.json | \
  sed "s/$1/$2/g" | sed "s/\"iso_url\": \".*\",/\"iso_url\": \"$URL\",/g" | sed "s/\"iso_checksum\": \".*\",/\"iso_checksum\": \"$4\",/g"`
PROVISIONERS=`jq "[ .provisioners[] | select( .only[0] // \"no\" | contains(\"$1\")) ]" generic-libvirt.json | sed "s/$1/$2/g"`
jq --argjson new1 "${PROVISIONERS}" --argjson new2 "${BUILDERS}" '.provisioners |= .[:-1] + $new1 + .[-1:] | .builders += $new2' generic-libvirt.json > generic-libvirt.new.json

BUILDERS=`jq "[ .builders[] | select( .name | contains(\"$1\")) ]" generic-parallels.json | \
  sed "s/$1/$2/g" | sed "s/\"iso_url\": \".*\",/\"iso_url\": \"$URL\",/g" | sed "s/\"iso_checksum\": \".*\",/\"iso_checksum\": \"$4\",/g"`
PROVISIONERS=`jq "[ .provisioners[] | select( .only[0] // \"no\" | contains(\"$1\")) ]" generic-parallels.json | sed "s/$1/$2/g"`
jq --argjson new1 "${PROVISIONERS}" --argjson new2 "${BUILDERS}" '.provisioners |= .[:-1] + $new1 + .[-1:] | .builders += $new2' generic-parallels.json > generic-parallels.new.json

BUILDERS=`jq "[ .builders[] | select( .name | contains(\"$1\")) ]" generic-virtualbox.json | \
  sed "s/$1/$2/g" | sed "s/\"iso_url\": \".*\",/\"iso_url\": \"$URL\",/g" | sed "s/\"iso_checksum\": \".*\",/\"iso_checksum\": \"$4\",/g"`
PROVISIONERS=`jq "[ .provisioners[] | select( .only[0] // \"no\" | contains(\"$1\")) ]" generic-virtualbox.json | sed "s/$1/$2/g"`
jq --argjson new1 "${PROVISIONERS}" --argjson new2 "${BUILDERS}" '.provisioners |= .[:-1] + $new1 + .[-1:] | .builders += $new2' generic-virtualbox.json > generic-virtualbox.new.json

# Duplicate Vagrantfile templates.
cp "tpl/generic-${1}.rb" "tpl/generic-${2}.rb"
cp "tpl/roboxes-${1}.rb" "tpl/roboxes-${2}.rb"

# Replace box names.
sed --in-place "s/$1/$2/g" "tpl/generic-${2}.rb"
sed --in-place "s/$1/$2/g" "tpl/roboxes-${2}.rb"

# Duplicate scripts directory.
cp --recursive "scripts/${1}" "scripts/${2}"

# Replace the box name inside scripts (if applicable).
find "scripts/${2}/" -type f -exec sed --in-place "s/$1/$2/g" {} \;

# Duplicate the auto-instll configs/scripts.
rename "http/generic.${1}" "http/generic.${2}" http/generic.${1}.* && git checkout "http/generic.${1}*"

# Replace the box name inside scripts (if applicable).
find "http/" -name "generic.${2}*" -type f -exec sed --in-place "s/$1/$2/g" {} \;

# Credentials and tokens.
if [ ! -f .credentialsrc ]; then
tput setaf 1; printf "\n\nThe credentials file is missing, so the validation is being skipped.\n\n\n"; tput sgr0
else

  # Import the credentials.
  source .credentialsrc

  # We need to specify a version, but since we aren't building at this point, any value should work.
  export VERSION="1.0.0"

  # We only validate these files, two at a time, because the packer validation process spwans 350+ processes.
  packer validate packer-cache.new.json &> /dev/null &
  P1=$!
  packer validate generic-hyperv.new.json &> /dev/null &
  P2=$!
  wait $P1 || (tput setaf 1; printf "\n\nTemplate validation failed.\n\n\n"; tput sgr0 ; exit 1)
  wait $P2 || (tput setaf 1; printf "\n\nTemplate validation failed.\n\n\n"; tput sgr0 ; exit 1)
  packer validate generic-vmware.new.json &> /dev/null &
  P1=$!
  packer validate generic-libvirt.new.json &> /dev/null &
  P2=$!
  wait $P1 || (tput setaf 1; printf "\n\nTemplate validation failed.\n\n\n"; tput sgr0 ; exit 1)
  wait $P2 || (tput setaf 1; printf "\n\nTemplate validation failed.\n\n\n"; tput sgr0 ; exit 1)
  packer validate generic-parallels.new.json &> /dev/null &
  P1=$!
  packer validate generic-virtualbox.new.json &> /dev/null &
  P2=$!
  wait $P1 || (tput setaf 1; printf "\n\nTemplate validation failed.\n\n\n"; tput sgr0 ; exit 1)
  wait $P2 || (tput setaf 1; printf "\n\nTemplate validation failed.\n\n\n"; tput sgr0 ; exit 1)

fi

mv packer-cache.new.json packer-cache.json
mv generic-hyperv.new.json generic-hyperv.json
mv generic-vmware.new.json generic-vmware.json
mv generic-libvirt.new.json generic-libvirt.json
mv generic-parallels.new.json generic-parallels.json
mv generic-virtualbox.new.json generic-virtualbox.json
