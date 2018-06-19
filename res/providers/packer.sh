#!/bin/bash

# Cross Platform Script Directory
pushd `dirname $0` > /dev/null
BASE=`pwd -P`
popd > /dev/null
cd $BASE

export GOPATH=$HOME/go/

# Cleanup any existing go directories.
rm -rf $GOPATH

# Fetch gox
go get github.com/mitchellh/gox && cd $GOPATH/src/github.com/mitchellh/gox
go build -o bin/gox .

# Fetch packer
go get github.com/hashicorp/packer && cd $GOPATH/src/github.com/hashicorp/packer

# For now, stick to the 1.2.4 version, as the 1.3.0 is too buggy.
#git checkout v1.2.4

# Apply the split function patch.
cat $BASE/packer-split-function.patch | patch -p1
#cat $HOME/6397.patch | patch -p1

# Customize
sed -i -e "s/common.Retry(10, 10, 3/common.Retry(10, 300, 32/g" post-processor/vagrant-cloud/step_upload.go

# Build for Linux, Darwin, and Windows
PATH=$GOPATH/bin:$PATH
XC_ARCH=amd64 XC_OS="windows darwin linux" scripts/build.sh

# Install
sudo install pkg/linux_amd64/packer /usr/local/bin/
sudo chown root:root /usr/local/bin/packer
sudo chcon unconfined_u:object_r:bin_t:s0 /usr/local/bin/packer

# Results
printf "\n\nBinaries\n"
printf "  $HOME/go/src/github.com/hashicorp/packer/pkg/linux_amd64/packer\n"
printf "  $HOME/go/src/github.com/hashicorp/packer/pkg/darwin_amd64/packer\n"
printf "  $HOME/go/src/github.com/hashicorp/packer/pkg/windows_amd64/packer\n\n\n"
