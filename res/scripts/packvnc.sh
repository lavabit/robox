#!/bin/bash

# Find the QEMU boxes.
PORT=`sudo netstat -pnl 2>&1 | grep tcp | grep -E "qemu|qemu-kvm" | awk -F':' '{print $2}' | awk -F' ' '{print $1}' | grep -E "^59"`
which vinagre &> /dev/null
if [ $? == 0 ]; then
  for p in $PORT; do
    #rpm -q virt-viewer &> /dev/null || (printf "\n\nA VNC port was detected, but the Virt Viewer doesn't appear to be available.\n\n" && exit 1)
    #remote-viewer vnc://127.0.0.1:$p &> /dev/null &
    CUT1="`echo $p | cut -b '3,4' -`"
    CUT2="`echo $CUT1 | sed 's/^0//g'`"
    COUNT="`ps -ef | grep qemu-kvm | grep --extended-regexp --count \"\\-vnc 127.0.0.1:$CUT1|\\-vnc 127.0.0.1:$CUT2\"`"
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

# Find the VirtualBox boxes and connect via RDP.
which vboxmanage &> /dev/null
if [ $? == 0 ]; then
  vboxmanage list vms | awk -F' ' '{print $2}' | while read BOX ; do 
    PORT=$(vboxmanage showvminfo "$BOX" --details 2>&1 | grep "VRDE property:" | grep "TCP/Ports" | grep -Eo '\"[0-9]*\"' | tr -d '\"' )
    vinagre --vnc-scale vnc://127.0.0.1:$PORT &> /dev/null &
  done 
fi

# An alternative method, using the VirtualBox GUI application instead of RDP.
# which vboxmanage &> /dev/null && which VirtualBox &> /dev/null
# if [ $? == 0 ]; then
#   vboxmanage list vms | awk -F' ' '{print $2}' | while read BOX ; do 
#     VirtualBox --startvm $BOX --no-startvm-errormsgbox --separate &> /dev/null &
#   done
# fi

exit 0
