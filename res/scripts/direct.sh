#!/bin/bash

# On MacOS the following utilities are needed.
# brew install --with-default-names jq gnu-sed coreutils
# BOXES=(`find output -type f -name "*.box"`)
# parallel -j 4 --xapply res/scripts/silent.sh {1} ::: "${BOXES[@]}"

# Handle self referencing, sourcing etc.
if [[ $0 != "${BASH_SOURCE[0]}" ]]; then
  export CMD="${BASH_SOURCE[0]}"
else
  export CMD=$0
fi

# Ensure a consistent working directory so relative paths work.
pushd "$(dirname "$CMD")" > /dev/null
BASE=$(pwd -P)
popd > /dev/null

# This logic allows us to force colorized output regardless of what 
# TERM and/or tput indicate. Activate forced color mode if COLORTERM is set 
# to any value, or if USE_ANSI_COLORS is set to 1, yes, or simply y. 
test -t 1 && {
  
  # Use ANSI escape sequences.
  case "$USE_ANSI_COLORS" in
    y|yes|Y|YES) USE_ANSI_COLORS=1 ;;
  esac
  test -n "${COLORTERM+set}" && : ${USE_ANSI_COLORS="1"}
  if test 1 = "$USE_ANSI_COLORS"; then
    
    # Modifiers
    T_BOLD="\e[0;1m" 
    T_ULINE="\e[0;4m"
    T_RESET="\e[0;0m"

    # Text Colors
    T_BLK="\e[0;30m" 
    T_RED="\e[0;31m" 
    T_GRN="\e[0;32m" 
    T_YEL="\e[0;33m" 
    T_BLU="\e[0;34m" 
    T_MAG="\e[0;35m" 
    T_CYN="\e[0;36m" 
    T_WHT="\e[0;37m" 

    # Text Colors (With Bold)
    T_BBLK="\e[1;30m"
    T_BRED="\e[1;31m"
    T_BGRN="\e[1;32m"
    T_BYEL="\e[1;33m"
    T_BBLU="\e[1;34m"
    T_BMAG="\e[1;35m"
    T_BCYN="\e[1;36m"
    T_BWHT="\e[1;37m"

  # Let tput decide.
  else
    test -n "$(tput sgr0 2>/dev/null)" && {
      
      # Modifiers
      T_RESET=$(tput sgr0)
      test -n "$(tput bold 2>/dev/null)" && T_BOLD=$(tput bold)
      test -n "$(tput sgr 0 1 2>/dev/null)" && T_ULINE=$(tput sgr 0 1)
      
      # Text Colors
      test -n "$(tput setaf 0 2>/dev/null)" && T_BLK=$(tput setaf 0)
      test -n "$(tput setaf 1 2>/dev/null)" && T_RED=$(tput setaf 1)
      test -n "$(tput setaf 2 2>/dev/null)" && T_GRN=$(tput setaf 2)
      test -n "$(tput setaf 3 2>/dev/null)" && T_YEL=$(tput setaf 3)
      test -n "$(tput setaf 4 2>/dev/null)" && T_BLU=$(tput setaf 4)
      test -n "$(tput setaf 5 2>/dev/null)" && T_MAG=$(tput setaf 5)
      test -n "$(tput setaf 6 2>/dev/null)" && T_CYN=$(tput setaf 6)
      test -n "$(tput setaf 7 2>/dev/null)" && T_WHT=$(tput setaf 7)
      
      # Text Colors (With Bold)
      T_BBLK="${T_BOLD}${T_BLK}"
      T_BRED="${T_BOLD}${T_RED}"
      T_BGRN="${T_BOLD}${T_GRN}"
      T_BYEL="${T_BOLD}${T_YEL}"
      T_BBLU="${T_BOLD}${T_BLU}"
      T_BMAG="${T_BOLD}${T_MAG}"
      T_BCYN="${T_BOLD}${T_CYN}"
      T_BWHT="${T_BOLD}${T_WHT}"
    }
  fi
}

if [ $# != 1 ] && [ $# != 2 ]; then
  printf "\n  Usage:\n    $0 FILENAME\n\n"
  exit 1
fi

# Make sure the recursion level is numeric.
if [ $# == 2 ] && [ -z "${2##*[!0-9]*}" ]; then
  printf "\n${T_RED}  Invalid recursion level. Exiting.${T_RESET}\n\n" >&2
  exit 1
fi

# Make sure the file exists.
if [ ! -f "$1" ]; then
  printf "\n${T_RED}  The $1 file does not exist. Exiting.${T_RESET}\n\n" >&2
  exit 1
fi

# If a second variable is provided then check to ensure we haven't hit the recursion limit.
if [ $# == 2 ] && [ "$2" -gt "10" ]; then
  printf "\n${T_RED}  The recursion level has been reached. Exiting.${T_RESET}\n\n" >&2
  exit 1
# Otherwise increment the level.
elif [ $# == 2 ]; then
  export RECURSION=$(($2+1))
# If no level is provided set an initial level of 0.
else
  export RECURSION=1
fi

if [ -f /opt/vagrant/embedded/lib64/libssl.so ] && [ -z "$LD_PRELOAD" ]; then
  export LD_PRELOAD="/opt/vagrant/embedded/lib64/libssl.so"
elif [ -f /opt/vagrant/embedded/lib64/libssl.so ]; then
  export LD_PRELOAD="/opt/vagrant/embedded/lib64/libssl.so:$LD_PRELOAD"
fi

if [ -f /opt/vagrant/embedded/lib64/libcrypto.so ] && [ -z "$LD_PRELOAD" ]; then
  export LD_PRELOAD="/opt/vagrant/embedded/lib64/libcrypto.so"
elif [ -f /opt/vagrant/embedded/lib64/libcrypto.so ]; then
  export LD_PRELOAD="/opt/vagrant/embedded/lib64/libcrypto.so:$LD_PRELOAD"
fi

export LD_LIBRARY_PATH="/opt/vagrant/embedded/bin/lib/:/opt/vagrant/embedded/lib64/"

if [[ "$(uname)" == "Darwin" ]]; then
  export CURL_CA_BUNDLE=/opt/vagrant/embedded/cacert.pem
fi

# The jq tool is needed to parse JSON responses.
if [ ! -f /usr/bin/jq ] && [ ! -f /usr/local/bin/jq ]; then
  printf "\n${T_RED}  The 'jq' utility is not installed. Exiting.${T_RESET}\n\n" >&2
  exit 1
fi

# Ensure the credentials file is available.
if [ -f "$BASE/../../.credentialsrc" ]; then
  source "$BASE/../../.credentialsrc"
else
  printf "\n${T_RED}  The credentials file is missing. Exiting.${T_RESET}\n\n" >&2
  exit 2
fi

if [ -z "${VAGRANT_CLOUD_TOKEN}" ]; then
  printf "\n${T_RED}  The vagrant cloud token is missing. Add it to the credentials file. Exiting.${T_RESET}\n\n" >&2
  exit 2
fi

# See if the log directory exists, if not create it.
if [ ! -d "$BASE/../../logs/" ]; then
  mkdir -p "$BASE/../../logs/" || mkdir "$BASE/../../logs"
fi

export UPLOAD_STD_LOGFILE="$BASE/../../logs/direct.txt"
export UPLOAD_ERR_LOGFILE="$BASE/../../logs/direct.errors.txt"

if [ -f /opt/vagrant/embedded/bin/curl ]; then
  export CURL="/opt/vagrant/embedded/bin/curl"
else
  export CURL="curl"
fi

FILENAME="$(basename "$1")"
FILEPATH="$(realpath "$1")"

ORG="$(echo "$FILENAME" | sed "s/\([a-z]*\)[\-]*\([a-z0-9-]*\)-\(hyperv\|vmware\|libvirt\|docker\|parallels\|virtualbox\)-\([0-9\.]*\).box/\1/g")"
BOX="$(echo "$FILENAME" | sed "s/\([a-z]*\)[-]*\([a-z0-9-]*\)-\(hyperv\|vmware\|libvirt\|docker\|parallels\|virtualbox\)-\([0-9\.]*\).box/\2/g")"
PROVIDER="$(echo "$FILENAME" | sed "s/\([a-z]*\)[-]*\([a-z0-9-]*\)-\(hyperv\|vmware\|libvirt\|docker\|parallels\|virtualbox\)-\([0-9\.]*\).box/\3/g")"
VERSION="$(echo "$FILENAME" | sed "s/\([a-z]*\)[-]*\([a-z0-9-]*\)-\(hyperv\|vmware\|libvirt\|docker\|parallels\|virtualbox\)-\([0-9\.]*\).box/\4/g")"

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
  BOX="$(echo $BOX | sed 's/-x32//g')"
fi

# Find the box checksum.
if [ -f "$FILEPATH.sha256" ]; then

  # Read the hash in from the checksum file.
  HASH="$(tail -1 "$FILEPATH.sha256" | awk -F' ' '{print $1}')"

else

  # Generate a hash using the box file.
  HASH="$(sha256sum "$FILEPATH" | awk -F' ' '{print $1}')"

fi

# Verify the values have been parsed properly.
if [ "$ORG" == "" ]; then
  printf "\n${T_RED}  The organization couldn't be parsed from the file name. Exiting.${T_RESET}\n\n" >&2
  exit 1
fi

if [ "$BOX" == "" ]; then
  printf "\n${T_RED}  The box name couldn't be parsed from the file name. Exiting.${T_RESET}\n\n" >&2
  exit 1
fi

if [ "$PROVIDER" == "" ]; then
  printf "\n${T_RED}  The provider couldn't be parsed from the file name. Exiting.${T_RESET}\n\n" >&2
  exit 1
fi

if [ "$VERSION" == "" ]; then
  printf "\n${T_RED}  The version couldn't be parsed from the file name. Exiting.${T_RESET}\n\n" >&2
  exit 1
fi

# Generate a hash using the box file if value is invalid.
if [ "$HASH" == "" ] || [ "$(echo "$HASH" | wc -c)" != 65 ]; then
  HASH="$(sha256sum "$FILEPATH" | awk -F' ' '{print $1}')"
fi

# If the hash is still invalid, then we report an error and exit.
if [ "$(echo "$HASH" | wc -c)" != 65 ]; then
  printf "\n${T_RED}  The hash couldn't be calculated properly. Exiting.${T_RESET}\n\n" >&2
  exit 1
fi

retry() {
  local COUNT=1
  local DELAY=0
  local RESULT=0
  while [[ "${COUNT}" -le 10 ]]; do
    [[ "${RESULT}" -ne 0 ]] && {
      printf "  ${*} ${T_BYEL}failed.${T_RESET}... retrying ${COUNT} of 10.\n" >&2
    }
    "${@}" && { RESULT=0 && break; } || RESULT="${?}"
    COUNT="$((COUNT + 1))"

    # Increase the delay with each iteration.
    DELAY="$((DELAY + 10))"
    sleep $DELAY
  done

  [[ "${COUNT}" -gt 10 ]] && {
    printf "${T_RED}  The command failed 10 times. ${T_RESET}\n" >&2
  }

  return "${RESULT}"
}

${CURL} \
  --tlsv1.2 \
  --silent \
  --retry 16 \
  --retry-delay 60 \
  --output /dev/null \
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
  " || \
  { printf "${T_BYEL}  Version creation failed. [ $ORG $BOX $PROVIDER $VERSION ]${T_RESET}\n" >&2 ; }

${CURL} \
  --silent \
  --retry 16 \
  --retry-delay 60 \
  --output /dev/null \
  --header "Authorization: Bearer $VAGRANT_CLOUD_TOKEN" \
  --request DELETE \
  "https://app.vagrantup.com/api/v1/box/$ORG/$BOX/version/$VERSION/provider/${PROVIDER}" || \
  { printf "${T_BYEL}  Unable to delete an existing version of the box. [ $ORG $BOX $PROVIDER $VERSION ]${T_RESET}\n" >&2 ; }

# Sleep to let the deletion propagate.
sleep 1

${CURL} \
  --tlsv1.2 \
  --silent \
  --retry 16 \
  --retry-delay 60 \
  --output /dev/null \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer $VAGRANT_CLOUD_TOKEN" \
  "https://app.vagrantup.com/api/v1/box/$ORG/$BOX/version/$VERSION/providers" \
  --data "{ \"provider\": { \"name\": \"$PROVIDER\", \"checksum\": \"$HASH\", \"checksum_type\": \"SHA256\" } }" || \
  { printf "${T_BYEL}  Unable to create a provider for this box version. [ $ORG $BOX $PROVIDER $VERSION ]${T_RESET}\n" >&2 ; }

UPLOAD_RESPONSE=$( ${CURL} \
  --fail \
  --show-error \
  --tlsv1.2 \
  --silent \
  --header "Authorization: Bearer $VAGRANT_CLOUD_TOKEN" \
  "https://app.vagrantup.com/api/v1/box/$ORG/$BOX/version/$VERSION/provider/$PROVIDER/upload/direct" )

UPLOAD_PATH="$(echo "$UPLOAD_RESPONSE" | jq -r .upload_path)"
UPLOAD_CALLBACK="$(echo "$UPLOAD_RESPONSE" | jq -r .callback)"

if [ "$UPLOAD_PATH" == "" ] || [ "$UPLOAD_PATH" == "echo" ] || [ "$UPLOAD_CALLBACK" == "" ] || [ "$UPLOAD_CALLBACK" == "echo" ]; then
   printf "\n${T_BYEL}  The $FILENAME file failed to upload. Restarting. [ $ORG $BOX $PROVIDER $VERSION / RECURSION = $RECURSION ]${T_RESET}\n\n" >&2
   exec "$0" "$1" $RECURSION
   exit $?
fi

# Sleep to give the cloud time to get setup.
sleep 1

retry ${CURL} --tlsv1.2 \
  --fail \
  --silent \
  --show-error \
  --request PUT \
  --max-time 7200 \
  --expect100-timeout 7200 \
  --header "Connection: keep-alive" \
  --write-out "FILE: $FILENAME\nCODE: %{http_code}\nIP: %{remote_ip}\nBYTES: %{size_upload}\nRATE: %{speed_upload}\nTOTAL TIME: %{time_total}\n\n" \
  --upload-file "$FILEPATH" "$UPLOAD_PATH" || \
  {
    printf "\n${T_BYEL}  The $FILENAME file failed to upload. Restarting. [ $ORG $BOX $PROVIDER $VERSION / RECURSION = $RECURSION ]${T_RESET}\n\n" >&2
    exec "$0" "$1" $RECURSION
    exit $?
  }

# Sleep to before trying the callback so the cloud can finish digestion.
sleep 1

# Submit the callback twice. hopefully this will reduce the number of boxes without valid download URLs.
${CURL} --tlsv1.2 \
  --silent \
  --output "/dev/null" \
  --show-error \
  --request PUT \
  --max-time 7200 \
  --header "Authorization: Bearer $VAGRANT_CLOUD_TOKEN" \
  "$UPLOAD_CALLBACK"

RESULT=$?
if [ "$RESULT" -ne 0 ]; then
  printf "${T_BYEL}  Upload failed. The callback returned an error. Retrying. [ $ORG $BOX $PROVIDER $VERSION / RESULT = $RESULT ]${T_RESET}\n" >&2 
  
  sleep 1
  ${CURL} --tlsv1.2 \
    --silent \
    --output "/dev/null" \
    --show-error \
    --request PUT \
    --max-time 7200 \
    --header "Authorization: Bearer $VAGRANT_CLOUD_TOKEN" \
    "$UPLOAD_CALLBACK"

  RESULT=$?
  if [ "$RESULT" -ne 0 ]; then
    printf "${T_BYEL}  Upload failed. The callback returned an error. Restarting. [ $ORG $BOX $PROVIDER $VERSION / RESULT = $RESULT / RECURSION = $RECURSION ]${T_RESET}\n\n" >&2
    exec "$0" "$1" $RECURSION
    exit $?
  fi
fi

# # Add a short pause, with the duration determined by the size of the file uploaded.
# PAUSE="`du -b $FILEPATH | awk -F' ' '{print $1}'`"
# bash -c "usleep $(($PAUSE/20))"
