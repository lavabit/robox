#!/bin/bash

# Sudo is needed to find the vmware-vmx ports.
PORT=`sudo netstat -pnl 2>&1 | grep tcp | grep -E "vmware-vmx|VBoxHeadless|qemu" | awk -F':' '{print $2}' | awk -F' ' '{print $1}' | grep -E "^59"`

for p in $PORT; do
  remote-viewer vnc://127.0.0.1:$p &> /dev/null &
done

exit 0
