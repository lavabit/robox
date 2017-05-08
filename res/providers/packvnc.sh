#!/bin/bash

# Sudo is needed to find the vmware-vmx ports.
PORT=`sudo netstat -pnl 2>&1 | grep tcp | grep -E "vmware-vmx|qemu|qemu-kvm" | awk -F':' '{print $2}' | awk -F' ' '{print $1}' | grep -E "^59"`

for p in $PORT; do
  #rpm -q virt-viewer &> /dev/null || (printf "\n\nA VNC port was detected, but the Virt Viewer doesn't appear to be available.\n\n" && exit 1)
  #remote-viewer vnc://127.0.0.1:$p &> /dev/null &
  rpm -q vinagre &> /dev/null || (printf "\n\nA VNC port was detected, but Vinagre doesn't appear to be available.\n\n" && exit 1)
  vinagre vnc://127.0.0.1:$p &> /dev/null &
done

# Sudo is also needed to find the virtualbox ports.
PORT=`sudo netstat -pnl 2>&1 | grep tcp | grep "VBoxHeadless" | awk -F':' '{print $2}' | awk -F' ' '{print $1}' | grep -E "^59"`

for p in $PORT; do
  rpm -q vinagre &> /dev/null || (printf "\n\nAn RDP port was detected, but Vinagre doesn't appear to be available.\n\n" && exit 1)
  vinagre --vnc-scale rdp://127.0.0.1:$p &> /dev/null &
done

exit 0
