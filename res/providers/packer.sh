#!/bin/bash

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
cd $BASE

export GOPATH=$HOME/go/

# Cleanup any existing go directories.
rm -rf $GOPATH

# Fetch gox
go get github.com/mitchellh/gox && cd $GOPATH/src/github.com/mitchellh/gox
go build -o bin/gox .

# Fetch packer
go get github.com/hashicorp/packer && cd $GOPATH/src/github.com/hashicorp/packer
# go get github.com/ladar/packer && cd $GOPATH/src/github.com/ladar/packer

# For now, stick to the 1.2.4 version, as the 1.3.0 is too buggy.
# git checkout v1.2.4

# Customize
sed -i -e "s/common.Retry(10, 10, 3/common.Retry(10, 10, 20/g" post-processor/vagrant-cloud/step_upload.go

# Increase the upload timeout
patch -p1 < $BASE/packer-upload-timeout.patch

# Fix the Hyper-V boot dervice ordering for generation one virtual machines.
patch -p1 < $BASE/hyperv-boot-order.patch

# Fox the Hyper-V SSH host value bug.
patch -p1 < $BASH/hyperv-ssh-host.patch

# Merged into packer version >= 1.3.4.
# patch -p1 < $BASE/hyperv-legacy-network-adapter.patch

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
