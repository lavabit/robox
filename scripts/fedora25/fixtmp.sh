#!/bin/bash

# Otherwise the tmp directory is a tiny ramdisk.
systemctl stop tmp.mount
systemctl mask tmp.mount

