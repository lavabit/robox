#!/bin/bash

PORT=`netstat -pnl 2>&1 | grep tcp | grep -E "vmware-vmx|virtualbox|qemu" | awk -F':' '{print $2}' | awk -F' ' '{print $1}' | grep -E "^59"`
remote-viewer vnc://127.0.0.1:$PORT &> /dev/null &
exit 0
