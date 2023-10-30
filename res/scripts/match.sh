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

if [ $# != 5 ]; then
  tput setaf 1; printf "\n\n  Usage:\n    $0 ORG BOX PROVIDER ARCH VERSION\n\n\n"; tput sgr0
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
if [ ! -f /usr/bin/sha256sum ]; then
  tput setaf 1; printf "\n\nThe 'sha256sum' utility is not installed.\n\n\n"; tput sgr0
  exit 1
fi

AGENT="Vagrant/2.4.0 (+https://www.vagrantup.com; ruby3.1.4)"

ORG="$1"
BOX="$2"
PROVIDER="$3"
ARCH="$4"
VERSION="$5"

# Handle the Vmware provider type.
if [ "$PROVIDER" == "vmware" ]; then
  PROVIDER="vmware_desktop"
fi

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

# Handle the arch types.
if [ "$ARCH" == "x64" ] || [ "$ARCH" == "x86_64" ] || [ "$ARCH" == "amd64" ]; then
  ARCH="amd64"
elif [ "$ARCH" == "x32" ] || [ "$ARCH" == "x86" ] || [ "$ARCH" == "i386" ] || [ "$ARCH" == "i686" ]; then
  ARCH="i386"
elif [ "$ARCH" == "a64" ] || [ "$ARCH" == "aarch64" ] || [ "$ARCH" == "arm64" ] || [ "$ARCH" == "arm64eb" ]|| [ "$ARCH" == "arm64le" ]; then
  ARCH="arm64"
elif [ "$ARCH" == "a32" ] || [ "$ARCH" == "armv7" ] || [ "$ARCH" == "armv6" ] || [ "$ARCH" == "arm" ] || [ "$ARCH" == "armeb" ] || [ "$ARCH" == "armle" ]; then
  ARCH="arm"
elif [ "$ARCH" == "p64" ] || [ "$ARCH" == "ppc64" ] || [ "$ARCH" == "power64" ] || [ "$ARCH" == "powerpc64" ]; then
  ARCH="ppc64"
elif [ "$ARCH" == "p32" ] || [ "$ARCH" == "ppc32" ] || [ "$ARCH" == "power" ] || [ "$ARCH" == "power32" ] || [ "$ARCH" == "powerpc" ] || [ "$ARCH" == "powerpc32" ] || [ "$ARCH" == "powerpcspe" ]; then
  ARCH="ppc"
elif [ "$ARCH" == "r64" ] || [ "$ARCH" == "riscv64" ] || [ "$ARCH" == "riscv64sf" ]; then
  ARCH="riscv64"
elif [ "$ARCH" == "r32" ] || [ "$ARCH" == "riscv" ] || [ "$ARCH" == "riscv32" ]; then
  ARCH="riscv32"
elif [ "$ARCH" == "m64" ] || [ "$ARCH" == "mips64" ] || [ "$ARCH" == "mips64hf" ] ; then
  ARCH="mips64"
elif [ "$ARCH" == "m32" ] || [ "$ARCH" == "mips" ] || [ "$ARCH" == "mips32" ] || [ "$ARCH" == "mipsn32" ] || [ "$ARCH" == "mipshf" ] ; then
  ARCH="mips"
elif  [ "$ARCH" == "ppc64le" ]; then
  ARCH="ppc64le"
elif [ "$ARCH" == "mips64le" ] || [ "$ARCH" == "mips64el" ] || [ "$ARCH" == "mips64hfel" ]; then
  ARCH="mips64le"
elif [ "$ARCH" == "mipsle" ] || [ "$ARCH" == "mipsel" ] || [ "$ARCH" == "mipselhf" ]; then
  ARCH="mipsle"
elif [ "$ARCH" != "" ]; then
  printf "\n${T_YEL}  The architecture is unrecognized. Passing it verbatim to the cloud. [ arch = ${ARCH} ]${T_RESET}\n\n" >&2
elif [ "$ARCH" == "" ]; then
  tput setaf 1; printf "\n\nThe arch couldn't be parsed correctly.\n\n\n"; tput sgr0
  exit 1
fi

# org name provider version hash
function download() {

  HASH=`${CURL} --silent --location --retry 10 --retry-delay 120 --max-redirs 10 --user-agent "${AGENT}" https://vagrantcloud.com/${ORG}/boxes/${BOX}/versions/${VERSION}/providers/${PROVIDER}/${ARCH}/vagrant.box | sha256sum`

  echo "$HASH" | grep --silent "$6"

  # The grep return code tells us whether it found a match in the header or not.
  if [ $? != 0 ]; then

    # Retry failed downloads, just in case the error was ephemeral.
    HASH=`${CURL} --silent --location --retry 10 --retry-delay 120 --max-redirs 10 --user-agent "${AGENT}" https://vagrantcloud.com/${ORG}/boxes/${BOX}/versions/${VERSION}/providers/${PROVIDER}/${ARCH}/vagrant.box | sha256sum`

    echo "$HASH" | grep --silent "$6"

    if [ $? != 0 ]; then
      printf "Box  -  "; tput setaf 1; printf "${ORG} ${BOX} ${PROVIDER} ${ARCH} ${VERSION}\n"; tput sgr0
    else
      printf "Box  +  "; tput setaf 2; printf "${ORG} ${BOX} ${PROVIDER} ${ARCH} ${VERSION}\n"; tput sgr0
    fi

  else
    printf "Box  +  "; tput setaf 2; printf "${ORG} ${BOX} ${PROVIDER} ${ARCH} ${VERSION}\n"; tput sgr0
  fi

  return 0
}

COUNT=1
DELAY=1
RESULT=0

while [[ "${COUNT}" -le 100 ]]; do
  RESULT=0
  DATA=`${CURL} --fail --silent --location --max-redirs 10 --connect-timeout 120 --speed-time 60 --speed-limit 1024 --user-agent "${AGENT}" https://app.vagrantup.com/api/v2/box/$ORG/$BOX/version/$VERSION`

  RESULT="${?}"
  if [[ $RESULT == 0 ]]; then
    break
  fi
  COUNT="$((COUNT + 1))"
  DELAY="$((DELAY + 1))"
  sleep $DELAY
done

CHECKSUM=`echo $DATA | jq -e -r ".providers[] | select( .name | contains(\"$PROVIDER\")) | select( .architecture | contains(\"$ARCH\")) | .checksum"`

if [ "$CHECKSUM" == "" ]; then
  tput setaf 1; printf "\n\nThe SHA 256 hash couldn't be retrieved from the server.\n\n\n"; tput sgr0
  exit 1
fi

if [ `echo "$CHECKSUM" | wc -c` != 65 ]; then
  tput setaf 1; printf "\n\nThe SHA 256 hash retrieved from the server isn't the correct length.\n\n\n"; tput sgr0
  exit 1
fi

download
