#!/bin/bash

# Find the QEMU boxes.
PORT=`sudo netstat -pnl 2>&1 | grep tcp | grep -E "qemu|qemu-kvm" | awk -F':' '{print $2}' | awk -F' ' '{print $1}' | grep -E "^59"`
which vinagre &> /dev/null
if [ $? == 0 ]; then
  for p in $PORT; do
    #rpm -q virt-viewer &> /dev/null || (printf "\n\nA VNC port was detected, but the Virt Viewer doesn't appear to be available.\n\n" && exit 1)
    #remote-viewer vnc://127.0.0.1:$p &> /dev/null &
    CUT="`echo $p | cut -b '3,4' -`"
    COUNT="`ps -ef | grep qemu-kvm | grep --extended-regexp --count \"\\-vnc 127.0.0.1:$CUT|\\-vnc 127.0.0.1:$((CUT))\"`"
    if [ "$COUNT" == 1 ]; then
      rpm -q vinagre  &> /dev/null || (printf "\n\nA VNC port was detected, but Vinagre doesn't appear to be available.\n\n" && exit 1)
      vinagre --vnc-scale vnc://127.0.0.1:$p &> /dev/null &
    fi
  done
fi

# Find the VMWare boxes.
PORT=`sudo netstat -pnl 2>&1 | grep tcp | grep -E "vmware-vmx" | awk -F':' '{print $2}' | awk -F' ' '{print $1}' | grep -E "^59"`
which vinagre &> /dev/null
if [ $? == 0 ]; then
for p in $PORT; do
  #rpm -q virt-viewer &> /dev/null || (printf "\n\nA VNC port was detected, but the Virt Viewer doesn't appear to be available.\n\n" && exit 1)
  #remote-viewer vnc://127.0.0.1:$p &> /dev/null &
  rpm -q vinagre  &> /dev/null || (printf "\n\nA VNC port was detected, but Vinagre doesn't appear to be available.\n\n" && exit 1)
  vinagre --vnc-scale vnc://127.0.0.1:$p &> /dev/null &
done
fi
# # Sudo is also needed to find the virtualbox ports.
# PORT=`sudo netstat -pnl 2>&1 | grep tcp | grep "VBoxHeadless" | awk -F':' '{print $2}' | awk -F' ' '{print $1}' | grep -E "^11"`
#
# for p in $PORT; do
#   rpm -q vinagre &> /dev/null || (printf "\n\nAn RDP port was detected, but Vinagre doesn't appear to be available.\n\n" && exit 1)
#   vinagre --vnc-scale rdp://127.0.0.1:$p &> /dev/null &
# done

# Find the VirtualBox boxes.
which vboxmanage &> /dev/null
if [ $? == 0 ]; then
VMS=`vboxmanage list vms | awk -F' ' '{print $1}' | awk -F'"' '{print $2}'`
for vm in $VMS; do
  VirtualBox --startvm $vm --no-startvm-errormsgbox --separate &> /dev/null &
done
fi

exit 0
