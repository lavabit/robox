#!/bin/bash
#
# This script imports a raw image into Docker.  It takes two
# arguments: the name of the image file, and the tag to assign to the
# Docker image that it creates.

usage() {
    echo "usage: $(basename $0) <image> <tag>"
    exit 1
}

image="$1"
tag="$2"

if [[ -z $1 || -z $2 ]]; then
    usage
fi

mount="$(mktemp -d --tmpdir)"
mount -o loop "$image" "$mount"

cd "$mount"

#this tar seems to cause issues such as rpmdb corruption
#tar -cpSf - --acls --selinux --xattrs * | docker import - "$tag"

tar --numeric-owner -c . | docker import - "$tag"

cd - >& /dev/null
umount "$mount"
rmdir "$mount"
