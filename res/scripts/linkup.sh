#!/bin/bash -eux

# Cross Platform Script Directory
pushd `dirname $0` > /dev/null
SCRIPT_PATH=`pwd -P`
popd > /dev/null
cd $SCRIPT_PATH

# Install the packvnc script.
if [ ! -d "$HOME/bin" ]; then
  mkdir -p "$HOME/bin/"
fi

cp packvnc.sh "$HOME/bin/packvnc"
chmod +x "$HOME/bin/packvnc"

cp boxes.sh "$HOME/bin/boxes"
chmod +x "$HOME/bin/boxes"
