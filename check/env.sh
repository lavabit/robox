#!/bin/bash

# Handle self referencing, sourcing etc.
if [[ $0 != $BASH_SOURCE ]]; then
  export CMD=$BASH_SOURCE
else
  export CMD=$0
fi

# Ensure a consistent working directory so relative paths work.
pushd "`dirname \"$CMD\"`" > /dev/null
BASE="`pwd -P`"
popd > /dev/null
cd "$BASE"
NAME="`basename \"$CMD\"`"

# Localize the Vagrant Home Directory
export VAGRANT_HOME=$BASE/vagrant.d/
