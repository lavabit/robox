#!/bin/bash

export GOPATH=$HOME/go/

# Fetch gox
go get github.com/mitchellh/gox && cd $GOPATH/src/github.com/mitchellh/gox 
go build -o bin/gox .

# Fetch packer
go get github.com/hashicorp/packer && cd $GOPATH/src/github.com/hashicorp/packer

# Customize
sed -i -e "s/common.Retry(10, 10, 3/common.Retry(10, 10, 256/g" post-processor/vagrant-cloud/step_upload.go

# Build for Linux
#go build -o bin/packer .

# Build for Windows and Linux
PATH=$GOPATH/bin:$PATH
XC_ARCH=amd64 XC_OS="windows linux" scripts/build.sh 

# Install
sudo mv pkg/linux_amd64/packer /usr/local/bin/
sudo chown root:root /usr/local/bin/packer
sudo chcon unconfined_u:object_r:bin_t:s0 /usr/local/bin/packer

