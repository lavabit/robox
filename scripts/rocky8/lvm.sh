#!/bin/bash -ex

VGID=$(vgdisplay --columns --noheadings --options vg_name)
PVID=$(vgdisplay --columns --noheadings --options pv_name $VGID)
LVID=$(df --output=source / | tail -1)
lvextend $LVID $PVID --resizefs || df -h

