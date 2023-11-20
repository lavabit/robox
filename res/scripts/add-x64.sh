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
if [ ! -f packer-cache-x64.json ]; then
  tput setaf 1; printf "\n packer-cache-x64.json file is missing.\n\n"; tput sgr0
  exit 1
elif [ ! -f generic-hyperv-x64.json ]; then
  tput setaf 1; printf "\n generic-hyperv-x64.json file is missing.\n\n"; tput sgr0
  exit 1
elif [ ! -f generic-vmware-x64.json ]; then
  tput setaf 1; printf "\n generic-vmware-x64.json file is missing.\n\n"; tput sgr0
  exit 1
elif [ ! -f generic-docker-x64.json ]; then
  tput setaf 1; printf "\n generic-docker-x64.json file is missing.\n\n"; tput sgr0
  exit 1
elif [ ! -f generic-libvirt-x64.json ]; then
  tput setaf 1; printf "\n generic-libvirt-x64.json file is missing.\n\n"; tput sgr0
  exit 1
elif [ ! -f generic-parallels-x64.json ]; then
  tput setaf 1; printf "\n generic-parallels-x64.json file is missing.\n\n"; tput sgr0
  exit 1
elif [ ! -f generic-virtualbox-x64.json ]; then
  tput setaf 1; printf "\n generic-virtualbox-x64.json file is missing.\n\n"; tput sgr0
  exit 1
fi

# Ensure we aren't overwriting unsaved changes.
if [ `git status --short packer-cache-x64.json | wc --lines` != 0 ]; then
  tput setaf 1; printf "\n packer-cache-x64.json file has uncommitted changes.\n\n"; tput sgr0
  exit 1
elif [ `git status --short generic-vmware-x64.json | wc --lines` != 0 ]; then
  tput setaf 1; printf "\n generic-vmware-x64.json file has uncommitted changes.\n\n"; tput sgr0
  exit 1
elif [ `git status --short generic-libvirt-x64.json | wc --lines` != 0 ]; then
  tput setaf 1; printf "\n generic-libvirt-x64.json file has uncommitted changes.\n\n"; tput sgr0
  exit 1
elif [ `git status --short generic-virtualbox-x64.json | wc --lines` != 0 ]; then
  tput setaf 1; printf "\n generic-virtualbox-x64.json file has uncommitted changes.\n\n"; tput sgr0
  exit 1
elif [ `git status --short generic-docker-x64.json | wc --lines` != 0 ]; then
  tput setaf 1; printf "\n generic-docker-x64.json file has uncommitted changes.\n\n"; tput sgr0
  exit 1
elif [ `git status --short generic-hyperv-x64.json | wc --lines` != 0 ]; then
  tput setaf 1; printf "\n generic-hyperv-x64.json file has uncommitted changes.\n\n"; tput sgr0
  exit 1
elif [ `git status --short generic-parallels-x64.json | wc --lines` != 0 ]; then
  tput setaf 1; printf "\n generic-parallels-x64.json file has uncommitted changes.\n\n"; tput sgr0
  exit 1
fi

URL=`printf "$3" | sed "s/\//\\\\\\\\\//g"`

# Add a cached config.
BUILDERS=`jq "[ .builders[] | select( .name | contains(\"$1\")) ]" packer-cache-x64.json | \
  sed "s/$1/$2/g" | sed "s/\"iso_url\": \".*\",/\"iso_url\": \"$URL\",/g" | sed "s/\"iso_checksum\": \".*\",/\"iso_checksum\": \"sha256:$4\",/g"`
jq --argjson new1 "${BUILDERS}" '.builders |= .[:-1] + $new1 + .[-1:]' packer-cache-x64.json > packer-cache-x64.new.json

BUILDERS=`jq "[ .builders[] | select( .name | contains(\"$1\")) ]" generic-hyperv-x64.json | \
  sed "s/$1/$2/g" | sed "s/\"iso_url\": \".*\",/\"iso_url\": \"$URL\",/g" | sed "s/\"iso_checksum\": \".*\",/\"iso_checksum\": \"sha256:$4\",/g"`
PROVISIONERS=`jq "[ .provisioners[] | select( .only[0] // \"no\" | contains(\"$1\")) ]" generic-hyperv-x64.json | sed "s/$1/$2/g"`
jq --argjson new1 "${PROVISIONERS}" --argjson new2 "${BUILDERS}" '.provisioners |= .[:-1] + $new1 + .[-1:] | .builders += $new2' generic-hyperv-x64.json > generic-hyperv.new-x64.json

BUILDERS=`jq "[ .builders[] | select( .name | contains(\"$1\")) ]" generic-vmware-x64.json | \
  sed "s/$1/$2/g" | sed "s/\"iso_url\": \".*\",/\"iso_url\": \"$URL\",/g" | sed "s/\"iso_checksum\": \".*\",/\"iso_checksum\": \"sha256:$4\",/g"`
PROVISIONERS=`jq "[ .provisioners[] | select( .only[0] // \"no\" | contains(\"$1\")) ]" generic-vmware-x64.json | sed "s/$1/$2/g"`
jq --argjson new1 "${PROVISIONERS}" --argjson new2 "${BUILDERS}" '.provisioners |= .[:-1] + $new1 + .[-1:] | .builders += $new2' generic-vmware-x64.json > generic-vmware.new-x64.json

BUILDERS=`jq "[ .builders[] | select( .name | contains(\"$1\")) ]" generic-libvirt-x64.json | \
  sed "s/$1/$2/g" | sed "s/\"iso_url\": \".*\",/\"iso_url\": \"$URL\",/g" | sed "s/\"iso_checksum\": \".*\",/\"iso_checksum\": \"sha256:$4\",/g"`
PROVISIONERS=`jq "[ .provisioners[] | select( .only[0] // \"no\" | contains(\"$1\")) ]" generic-libvirt-x64.json | sed "s/$1/$2/g"`
jq --argjson new1 "${PROVISIONERS}" --argjson new2 "${BUILDERS}" '.provisioners |= .[:-1] + $new1 + .[-1:] | .builders += $new2' generic-libvirt-x64.json > generic-libvirt.new-x64.json

BUILDERS=`jq "[ .builders[] | select( .name | contains(\"$1\")) ]" generic-docker-x64.json | \
  sed "s/$1/$2/g" | sed "s/\"iso_url\": \".*\",/\"iso_url\": \"$URL\",/g" | sed "s/\"iso_checksum\": \".*\",/\"iso_checksum\": \"sha256:$4\",/g"`
PROVISIONERS=`jq "[ .provisioners[] | select( .only[0] // \"no\" | contains(\"$1\")) ]" generic-docker-x64.json | sed "s/$1/$2/g"`
jq --argjson new1 "${PROVISIONERS}" --argjson new2 "${BUILDERS}" '.provisioners |= .[:-1] + $new1 + .[-1:] | .builders += $new2' generic-docker-x64.json > generic-docker.new-x64.json

BUILDERS=`jq "[ .builders[] | select( .name | contains(\"$1\")) ]" generic-parallels-x64.json | \
  sed "s/$1/$2/g" | sed "s/\"iso_url\": \".*\",/\"iso_url\": \"$URL\",/g" | sed "s/\"iso_checksum\": \".*\",/\"iso_checksum\": \"sha256:$4\",/g"`
PROVISIONERS=`jq "[ .provisioners[] | select( .only[0] // \"no\" | contains(\"$1\")) ]" generic-parallels-x64.json | sed "s/$1/$2/g"`
jq --argjson new1 "${PROVISIONERS}" --argjson new2 "${BUILDERS}" '.provisioners |= .[:-1] + $new1 + .[-1:] | .builders += $new2' generic-parallels-x64.json > generic-parallels.new-x64.json

BUILDERS=`jq "[ .builders[] | select( .name | contains(\"$1\")) ]" generic-virtualbox-x64.json | \
  sed "s/$1/$2/g" | sed "s/\"iso_url\": \".*\",/\"iso_url\": \"$URL\",/g" | sed "s/\"iso_checksum\": \".*\",/\"iso_checksum\": \"sha256:$4\",/g"`
PROVISIONERS=`jq "[ .provisioners[] | select( .only[0] // \"no\" | contains(\"$1\")) ]" generic-virtualbox-x64.json | sed "s/$1/$2/g"`
jq --argjson new1 "${PROVISIONERS}" --argjson new2 "${BUILDERS}" '.provisioners |= .[:-1] + $new1 + .[-1:] | .builders += $new2' generic-virtualbox-x64.json > generic-virtualbox.new-x64.json

# Duplicate Vagrantfile templates.
[ ! -f  "tpl/generic-${2}.rb" ] && { cp "tpl/generic-${1}.rb" "tpl/generic-${2}.rb" && sed --in-place "s/$1/$2/g" "tpl/generic-${2}.rb" ; }
[ ! -f  "tpl/roboxes-${2}.rb" ] && { cp "tpl/roboxes-${1}.rb" "tpl/roboxes-${2}.rb" && sed --in-place "s/$1/$2/g" "tpl/roboxes-${2}.rb" ; }

# Duplicate scripts directory and replace the box name inside scripts (if applicable).
[ ! -d "scripts/${2}" ] && { cp --recursive "scripts/${1}" "scripts/${2}" && find "scripts/${2}/" -type f -exec sed --in-place "s/$1/$2/g" {} \; ; }

# Duplicate the auto-install configs/scripts and replace the box name inside scripts (if applicable).
[ "$(ls http/generic.$2)" ] && {
  rename "http/generic.${1}" "http/generic.${2}" http/generic.${1}.* && git checkout "http/generic.${1}*" ;
  find "http/" -name "generic.${2}*" -type f -exec sed --in-place "s/$1/$2/g" {} \; ;
}

# Update the git ignore file in the check directory.
grep ${1} "check/.gitignore" | sed "s/$1/$2/g" >> "check/.gitignore"
cat "check/.gitignore" | sort --version-sort | uniq > "check/gitignore.new"
[ -f "check/gitignore.new" ] && mv --force "check/gitignore.new" "check/.gitignore"

# Create a Vagrant template in the check directory.
cp "check/${1}.tpl" "check/${2}.tpl"
sed --in-place "s/$1/$2/g" "check/${2}.tpl"

# Add new rules/commands to the check script.
IFS=':' 
grep --no-filename --line-number ${1} "check/check.sh" | sort --reverse --numeric-sort | sed "s/$1/$2/g" | while read NUM LINE; do
  let NUM+=1
  sed --in-place "${NUM} i\\$LINE" "check/check.sh"
done
unset IFS

# Specify dummy values for the template variables to facilitate validation.
export VERSION="1.0.0"
export QUAY_USER="user"
export DOCKER_USER="user"
export QUAY_PASSWORD="password"
export DOCKER_PASSWORD="password"

# We only validate these files, two at a time, because the packer validation process spawns 350+ processes.
nice -n +19 packer validate packer-cache-x64.new.json &> /dev/null &
# P1=$!
# nice -n +19 packer validate packer-cache-x32.new.json &> /dev/null &
# P2=$!  
# nice -n +19 packer validate packer-cache-a64.new.json &> /dev/null &
# P3=$!
# nice -n +19 packer validate packer-cache-a32.new.json &> /dev/null &
# P4=$!  
nice -n +19 packer validate generic-hyperv.new-x64.json &> /dev/null &
P5=$!  
nice -n +19 packer validate generic-docker.new-x64.json &> /dev/null &
P6=$!

wait $P1 || { tput setaf 1; printf "\n\nThe new packer-cache-x64 template validation failed.\n\n\n"; tput sgr0; exit 1; }
# wait $P2 || { tput setaf 1; printf "\n\nThe new packer-cache-x32 template validation failed.\n\n\n"; tput sgr0; exit 1; }
# wait $P3 || { tput setaf 1; printf "\n\nThe new packer-cache-a64 template validation failed.\n\n\n"; tput sgr0; exit 1; }
# wait $P4 || { tput setaf 1; printf "\n\nThe new packer-cache-a32 template validation failed.\n\n\n"; tput sgr0; exit 1; }
wait $P5 || { tput setaf 1; printf "\n\nThe new generic-hyperv-x64.json template validation failed.\n\n\n"; tput sgr0; exit 1; }
wait $P6 || { tput setaf 1; printf "\n\nThe new generic-docker-x64.json template validation failed.\n\n\n"; tput sgr0; exit 1; }

nice -n +19 packer validate generic-vmware.new-x64.json &> /dev/null &
P7=$! 
nice -n +19 packer validate generic-libvirt.new-x64.json &> /dev/null &
P8=$! 
nice -n +19 packer validate generic-parallels.new-x64.json &> /dev/null &
P9=$!
nice -n +19 packer validate generic-virtualbox.new-x64.json &> /dev/null &
P10=$!

wait $P7 || { tput setaf 1; printf "\n\nThe new generic-vmware-x64.json template validation failed.\n\n\n"; tput sgr0; exit 1; }
wait $P8 || { tput setaf 1; printf "\n\nThe new generic-libvirt-x64.json template validation failed.\n\n\n"; tput sgr0; exit 1; }
wait $P9 || { tput setaf 1; printf "\n\nThe new generic-parallels-x64.json template validation failed.\n\n\n"; tput sgr0; exit 1; }
wait $P10 || { tput setaf 1; printf "\n\nThe new generic-virtualbox-x64.json template validation failed.\n\n\n"; tput sgr0; exit 1; }

# nice -n +19 packer validate generic-vmware.new-x32.json &> /dev/null &
# P11=$!
# nice -n +19 packer validate generic-libvirt.new-x32.json &> /dev/null &
# P12=$!
# nice -n +19 packer validate generic-virtualbox.new-x32.json &> /dev/null &
# P13=$!

# wait $P11 || { tput setaf 1; printf "\n\nThe new generic-vmware-x32.json template validation failed.\n\n\n"; tput sgr0; exit 1; }
# wait $P12 || { tput setaf 1; printf "\n\nThe new generic-libvirt-x32.json template validation failed.\n\n\n"; tput sgr0; exit 1; }
# wait $P13 || { tput setaf 1; printf "\n\nThe new generic-virtualbox-x32.json template validation failed.\n\n\n"; tput sgr0; exit 1; }

# nice -n +19 packer validate generic-libvirt.new-a64.json &> /dev/null &
# P14=$!
# nice -n +19 packer validate generic-libvirt.new-a32.json &> /dev/null &
# P15=$!

# wait $P14 || { tput setaf 1; printf "\n\nThe new generic-libvirt-a64.json template validation failed.\n\n\n"; tput sgr0; exit 1; }
# wait $P15 || { tput setaf 1; printf "\n\nThe new generic-libvirt-a32.json template validation failed.\n\n\n"; tput sgr0; exit 1; }

mv packer-cache-x64.new.json packer-cache-x64.json

mv generic-libvirt.new-x64.json generic-libvirt-x64.json
mv generic-virtualbox.new-x64.json generic-virtualbox-x64.json
mv generic-vmware.new-x64.json generic-vmware-x64.json
mv generic-hyperv.new-x64.json generic-hyperv-x64.json
mv generic-docker.new-x64.json generic-docker-x64.json
mv generic-parallels.new-x64.json generic-parallels-x64.json

tput sgr0

