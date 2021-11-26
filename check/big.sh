#!/bin/bash

# find *.tpl -type f -name "*.tpl" -exec ./big.sh {} \;

if [ ! -f "$1" ]; then
  echo "The file $1 appears to be missing."
  exit 1
fi

# Hyper-V and libvirt
sed -i -e 's|v.maxmemory = 1024|v.maxmemory = 2048|g' $1
sed -i -e 's|v.memory = 1024|v.memory = 2048|g' $1
sed -i -e 's|v.cpus = 1|v.cpus = 2|g' $1

# Virtualbox
sed -i -e 's|v.customize \["modifyvm", :id, "--memory", 1024\]|v.customize ["modifyvm", :id, "--memory", 2048]|g' $1
sed -i -e 's|v.customize \["modifyvm", :id, "--cpus", 1\]|v.customize ["modifyvm", :id, "--cpus", 2]|g' $1

# VMWare
sed -i -e 's|v.vmx\["memsize"\] = "1024"|v.vmx["memsize"] = "2048"|g' $1
sed -i -e 's|v.vmx\["numvcpus"\] = "1"|v.vmx["numvcpus"] = "2"|g' $1
