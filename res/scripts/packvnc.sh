#!/bin/bash

# Find a VNC client.
if [ $(command -v remote-viewer &> /dev/null && echo $?) ]; then
  export VNCVIEWER="remote-viewer"
elif [ $(command -v vinagre &> /dev/null && echo $?) ]; then
  export VNCVIEWER="vinagre --vnc-scale"
elif [ $(command -v remmina &> /dev/null && echo $?) ]; then
  export VNCVIEWER="remmina"
else
  export VNCVIEWER="echo"
fi

if [ $(command -v rdesktop &> /dev/null && echo $?) ]; then
  export RDPVIEWER="rdesktop"
elif [ $(command -v vinagre &> /dev/null && echo $?) ]; then
  export RDPVIEWER="vinagre"
else
  export RDPVIEWER="echo"
fi


# Find the QEMU boxes.
PORT=`sudo netstat -pnl 2>&1 | grep tcp | grep -E "/qemu|/qemu-kvm|/qemu-system-" | awk -F':' '{print $2}' | awk -F' ' '{print $1}' | grep -E "^59"`
for p in $PORT; do
  ${VNCVIEWER} vnc://127.0.0.1:$p &> /dev/null &
done


# Find the VMWare boxes.
PORT=`sudo netstat -pnl 2>&1 | grep tcp | grep -E "vmware-vmx" | awk -F':' '{print $2}' | awk -F' ' '{print $1}' | grep -E "^59"`
for p in $PORT; do
  ${VNCVIEWER} vnc://127.0.0.1:$p &> /dev/null &
done

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
    ${RDPVIEWER} rdp://127.0.0.1:$PORT &> /dev/null &
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
