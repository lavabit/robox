#!/bin/bash

# On MacOS the following utilities are needed.
# brew install --with-default-names jq gnu-sed coreutils
# BOXES=(`find output -type f -name "*.box"`)
# parallel -j 4 --xapply res/scripts/silent.sh {1} ::: "${BOXES[@]}"

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

ORG=`echo "$FILENAME" | sed "s/\([a-z]*\)[\-]*\([a-z0-9-]*\)-\(hyperv\|vmware\|libvirt\|docker\|parallels\|virtualbox\)-\([a-z0-9-]*\)-\([0-9\.]*\).box/\1/g"`
BOX=`echo "$FILENAME" | sed "s/\([a-z]*\)[-]*\([a-z0-9-]*\)-\(hyperv\|vmware\|libvirt\|docker\|parallels\|virtualbox\)-\([a-z0-9-]*\)-\([0-9\.]*\).box/\2/g"`
PROVIDER=`echo "$FILENAME" | sed "s/\([a-z]*\)[-]*\([a-z0-9-]*\)-\(hyperv\|vmware\|libvirt\|docker\|parallels\|virtualbox\)-\([a-z0-9-]*\)-\([0-9\.]*\).box/\3/g"`
ARCH=`echo "$FILENAME" | sed "s/\([a-z]*\)[-]*\([a-z0-9-]*\)-\(hyperv\|vmware\|libvirt\|docker\|parallels\|virtualbox\)-\([a-z0-9-]*\)-\([0-9\.]*\).box/\4/g"`
VERSION=`echo "$FILENAME" | sed "s/\([a-z]*\)[-]*\([a-z0-9-]*\)-\(hyperv\|vmware\|libvirt\|docker\|parallels\|virtualbox\)-\([a-z0-9-]*\)-\([0-9\.]*\).box/\5/g"`

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

# Handle the arch types.
if [ "$ARCH" == "x64" ] || [ "$ARCH" == "x86_64" ] || [ "$ARCH" == "amd64" ]; then
  ARCH="amd64"
elif [ "$ARCH" == "x32" ] || [ "$ARCH" == "x86" ] || [ "$ARCH" == "i386" ] || [ "$ARCH" == "i686" ]; then
  ARCH="i386"
elif [ "$ARCH" == "a64" ] || [ "$ARCH" == "aarch64" ] || [ "$ARCH" == "arm64" ] || [ "$ARCH" == "arm64eb" ]|| [ "$ARCH" == "arm64le" ]; then
  ARCH="arm64"
elif [ "$ARCH" == "a32" ] || [ "$ARCH" == "armv7" ] || [ "$ARCH" == "armv6" ] || [ "$ARCH" == "arm" ] || [ "$ARCH" == "armeb" ] || [ "$ARCH" == "armle" ] || [ "$ARCH" == "armel" ] || [ "$ARCH" == "armhf" ]; then
  ARCH="arm"
elif [ "$ARCH" == "m64" ] || [ "$ARCH" == "mips64le" ] || [ "$ARCH" == "mips64el" ] || [ "$ARCH" == "mips64hfel" ]; then
  ARCH="mips64le"
elif [ "$ARCH" == "mips64" ] || [ "$ARCH" == "mips64hf" ] ; then
  ARCH="mips64"
elif [ "$ARCH" == "m32" ] || [ "$ARCH" == "mips" ] || [ "$ARCH" == "mips32" ] || [ "$ARCH" == "mipsn32" ] || [ "$ARCH" == "mipshf" ] ; then
  ARCH="mips"
elif [ "$ARCH" == "mipsle" ] || [ "$ARCH" == "mipsel" ] || [ "$ARCH" == "mipselhf" ]; then
  ARCH="mipsle"
elif [ "$ARCH" == "p64" ] || [ "$ARCH" == "ppc64le" ]; then
  ARCH="ppc64le"
elif [ "$ARCH" == "ppc64" ] || [ "$ARCH" == "power64" ] || [ "$ARCH" == "powerpc64" ]; then
  ARCH="ppc64"
elif [ "$ARCH" == "p32" ] || [ "$ARCH" == "ppc32" ] || [ "$ARCH" == "power" ] || [ "$ARCH" == "power32" ] || [ "$ARCH" == "powerpc" ] || [ "$ARCH" == "powerpc32" ] || [ "$ARCH" == "powerpcspe" ]; then
  ARCH="ppc"
elif [ "$ARCH" == "r64" ] || [ "$ARCH" == "riscv64" ] || [ "$ARCH" == "riscv64sf" ]; then
  ARCH="riscv64"
elif [ "$ARCH" == "r32" ] || [ "$ARCH" == "riscv" ] || [ "$ARCH" == "riscv32" ]; then
  ARCH="riscv"
else
  printf "\n${T_YEL}  The architecture is unrecognized. Passing it verbatim to the cloud. [ arch = ${ARCH} ]${T_RESET}\n\n" >&2
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

if [ "$ARCH" == "" ]; then
  printf "\n${T_RED}  The architecture couldn't be parsed from the file name. Exiting.${T_RESET}\n\n" >&2
  exit 1
fi

if [ "$VERSION" == "" ]; then
  tput setaf 1; printf "\n\nThe version couldn't be parsed from the file name.\n\n\n"; tput sgr0
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


function release_box() {

tput setaf 5; printf "Release the version.\n"; tput sgr0
retry ${CURL} \
  --tlsv1.2 \
  --silent \
  --header "Authorization: Bearer $VAGRANT_CLOUD_TOKEN" \
  https://app.vagrantup.com/api/v2/box/$ORG/$BOX/version/$VERSION/release \
  --request PUT | jq  --color-output '.status,.version,.providers[]' | grep -vE "hosted|hosted_token|original_url|created_at|updated_at|\}|\{"

}

release_box

if [ "$ORG" == "generic" ] && [ "$ARCH" == "amd64" ]; then
  sleep 8 ; VAGRANTPATH="vagrantcloud.com" ; ORG="generic-x64"
  release_box
elif [ "$ORG" == "generic" ] && [ "$ARCH" == "i386" ]; then
  sleep 8 ; VAGRANTPATH="vagrantcloud.com" ; ORG="generic-x32"
  release_box
elif [ "$ORG" == "generic" ] && [ "$ARCH" == "arm64" ]; then
  sleep 8 ; VAGRANTPATH="vagrantcloud.com" ; ORG="generic-a64"
  release_box
elif [ "$ORG" == "generic" ] && [ "$ARCH" == "arm" ]; then
  sleep 8 ; VAGRANTPATH="vagrantcloud.com" ; ORG="generic-a32"
  release_box
elif [ "$ORG" == "generic" ] && [ "$ARCH" == "mips64le" ]; then
  sleep 8 ; VAGRANTPATH="vagrantcloud.com" ; ORG="generic-m64"
  release_box
elif [ "$ORG" == "generic" ] && [ "$ARCH" == "mips" ]; then
  sleep 8 ; VAGRANTPATH="vagrantcloud.com" ; ORG="generic-m32"
  release_box
elif [ "$ORG" == "generic" ] && [ "$ARCH" == "ppc64le" ]; then
  sleep 8 ; VAGRANTPATH="vagrantcloud.com" ; ORG="generic-p64"
  release_box
elif [ "$ORG" == "generic" ] && [ "$ARCH" == "ppc" ]; then
  sleep 8 ; VAGRANTPATH="vagrantcloud.com" ; ORG="generic-p32"
  release_box
elif [ "$ORG" == "generic" ] && [ "$ARCH" == "riscv64" ]; then
  sleep 8 ; VAGRANTPATH="vagrantcloud.com" ; ORG="generic-r64"
  release_box
elif [ "$ORG" == "generic" ] && [ "$ARCH" == "riscv" ]; then
  sleep 8 ; VAGRANTPATH="vagrantcloud.com" ; ORG="generic-r32"
  release_box
elif [ "$ORG" == "roboxes" ] && [ "$ARCH" == "amd64" ]; then
  sleep 8 ; VAGRANTPATH="vagrantcloud.com" ; ORG="roboxes-x64"
  release_box
elif [ "$ORG" == "roboxes" ] && [ "$ARCH" == "i386" ]; then
  sleep 8 ; VAGRANTPATH="vagrantcloud.com" ; ORG="roboxes-x32"
  release_box
elif [ "$ORG" == "roboxes" ] && [ "$ARCH" == "arm64" ]; then
  sleep 8 ; VAGRANTPATH="vagrantcloud.com" ; ORG="roboxes-a64"
  release_box
elif [ "$ORG" == "roboxes" ] && [ "$ARCH" == "arm" ]; then
  sleep 8 ; VAGRANTPATH="vagrantcloud.com" ; ORG="roboxes-a32"
  release_box
elif [ "$ORG" == "roboxes" ] && [ "$ARCH" == "mips64le" ]; then
  sleep 8 ; VAGRANTPATH="vagrantcloud.com" ; ORG="roboxes-m64"
  release_box
elif [ "$ORG" == "roboxes" ] && [ "$ARCH" == "mips" ]; then
  sleep 8 ; VAGRANTPATH="vagrantcloud.com" ; ORG="roboxes-m32"
  release_box
elif [ "$ORG" == "roboxes" ] && [ "$ARCH" == "ppc64le" ]; then
  sleep 8 ; VAGRANTPATH="vagrantcloud.com" ; ORG="roboxes-p64"
  release_box
elif [ "$ORG" == "roboxes" ] && [ "$ARCH" == "ppc" ]; then
  sleep 8 ; VAGRANTPATH="vagrantcloud.com" ; ORG="roboxes-p32"
  release_box
elif [ "$ORG" == "roboxes" ] && [ "$ARCH" == "riscv64" ]; then
  sleep 8 ; VAGRANTPATH="vagrantcloud.com" ; ORG="roboxes-r64"
  release_box
elif [ "$ORG" == "roboxes" ] && [ "$ARCH" == "riscv" ]; then
  sleep 8 ; VAGRANTPATH="vagrantcloud.com" ; ORG="roboxes-r32"
  release_box
fi

