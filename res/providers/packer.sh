#!/bin/bash

export GOPATH=$HOME/go/

# Fetch
go get github.com/hashicorp/packer && cd $GOPATH/src/github.com/hashicorp/packer

# Customize
sed -i -e "s/common.Retry(10, 10, 3/common.Retry(10, 10, 256/g" post-processor/vagrant-cloud/step_upload.go

# Build
go build -o bin/packer .

# Install
sudo mv bin/packer /usr/local/bin/
sudo chown root:root /usr/local/bin/packer
sudo chcon unconfined_u:object_r:bin_t:s0 /usr/local/bin/packer

