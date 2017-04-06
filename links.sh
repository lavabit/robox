#!/bin/bash

function validate {

  # Grab just the response header and look for the 200 response code to indicate the link is valid.
  curl --silent --head  $1 | head -1 | grep --silent --extended-regexp "HTTP/1\.1 200 OK|HTTP/2\.0 200 OK"

  # The grep return code tells us whether it found a match in the header or not.
  if [ $? != 0 ]; then
    printf "Invalid link:\n\t$1\n\n"
  fi

}

# Collect the list of ISO urls.
ISOURLS=`grep iso_url *.json | awk -F'"' '{print $4}'`

# Greet the user.
printf "\nFound %i links...\n\n" `echo $ISOURLS | wc --words`

for l in $ISOURLS; do
  validate $l
done
