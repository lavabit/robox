#!/bin/bash

# find *.tpl -type f -name "*.tpl" -exec ./little.sh {} \;

if [ ! -f "$1" ]; then
  echo "The file $1 appears to be missing."
  exit 1
fi

# Hyper-V and libvirt
sed -i -e 's|v.maxmemory = 2048|v.maxmemory = 1024|g' $1
sed -i -e 's|v.memory = 2048|v.memory = 1024|g' $1
sed -i -e 's|v.cpus = 2|v.cpus = 1|g' $1

# Virtualbox
sed -i -e 's|v.customize \["modifyvm", :id, "--memory", 2048\]|v.customize ["modifyvm", :id, "--memory", 1024]|g' $1
sed -i -e 's|v.customize \["modifyvm", :id, "--cpus", 2\]|v.customize ["modifyvm", :id, "--cpus", 1]|g' $1

# VMWare
sed -i -e 's|v.vmx\["memsize"\] = "2048"|v.vmx["memsize"] = "1024"|g' $1
sed -i -e 's|v.vmx\["numvcpus"\] = "2"|v.vmx["numvcpus"] = "1"|g' $1
