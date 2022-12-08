#!/bin/bash

# Otherwise the tmp directory is a tiny ramdisk.
systemctl --quiet is-active tmp.mount && systemctl stop tmp.mount
systemctl --quiet is-enabled tmp.mount && systemctl disable tmp.mount
systemctl mask tmp.mount

