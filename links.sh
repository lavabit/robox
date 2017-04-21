#!/bin/bash

function validate {

  # Grab just the response header and look for the 200 response code to indicate the link is valid.
  curl --silent --head "$1" | head -1 | grep --silent --extended-regexp "HTTP/1\.1 200 OK|HTTP/2\.0 200 OK"

  # The grep return code tells us whether it found a match in the header or not.
  if [ $? != 0 ]; then
    printf "Link Failure:  $1\n"
    return 1
  fi

  # Grab the ISO and pipe the data through sha256sum, then compare the checksum value.
  curl --silent "$1" | sha256sum | grep --silent "$2"

  # The grep return code tells us whether it found a match in the header or not.
  if [ $? != 0 ]; then
    SUM=`curl --silent "$1" | sha256sum | awk -F' ' '{print $1}'`
    printf "Hash Failure:  $1\n"
    printf "   Expected -  $2\n"
    printf "      Found -  $SUM\n"
    return 1
  fi

  printf "Validated   :  $1\n"
  return 0
}

# Count the failures.
FAILURES=0

# Collect the list of ISO urls.
ISOURLS=(`grep -E "iso_url|guest_additions_url" magma-docker.json magma-libvirt.json magma-vmware.json magma-virtualbox.json | awk -F'"' '{print $4}'`)
ISOSUMS=(`grep -E "iso_checksum|guest_additions_sha256" magma-docker.json magma-libvirt.json magma-vmware.json magma-virtualbox.json | grep -v "iso_checksum_type" | awk -F'"' '{print $4}'`)

# Greet the user.
printf "\nFound ${#ISOURLS[@]} links...\n\n"

for ((i = 0; i < ${#ISOURLS[@]}; ++i)); do
    validate "${ISOURLS[$i]}" "${ISOSUMS[$i]}"
    if [ $? != 0 ]; then
      FAILURES=$(( $FAILURES + 1 ))
    fi
done

# If any of the links fail, output an extra line to make things cleaner.
if [ $FAILURES != 0 ]; then
  printf "\nA total of $FAILURES links failed...\n"
fi
printf "\n"
