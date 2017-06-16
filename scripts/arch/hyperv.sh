#!/bin/bash

# hypervvsh
git clone https://aur.archlinux.org/hypervvssd.git
cd hypervvssd
makepkg -Sri
cd ..

# hypervkvpd
git clone https://aur.archlinux.org/hypervkvpd.git
cd hypervkvpd
makepkg -Sri
cd ..

# hypervfcopyd
git clone https://aur.archlinux.org/hypervfcopyd.git
cd hypervfcopyd
makepkg -Sri
cd ..

exit 0
