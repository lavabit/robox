#!/bin/bash

# Otherwise the tmp directory is a tiny ramdisk.
systemctl disable tmp.mount
systemctl stop tmp.mount
systemctl mask tmp.mount

