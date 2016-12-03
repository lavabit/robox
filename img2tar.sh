#!/bin/bash
#
# This script imports a raw image into Docker consumeable tarball.  It takes one
# arguments: the name of the image file

usage() {
    echo "usage: $(basename $0) <image>"
    exit 1
}

image="$1"

if [[ -z $1 ]]; then
    usage
fi

mount="$(mktemp -d --tmpdir)"
mount -o loop "$image" "$mount"

cd "$mount"
#this tar seems to cause issues such as rpmdb corruption
#tar -cpSf - --acls --selinux --xattrs * | bzip2 > ${image}.tar.bz2

# This one appears to work fine for docker creation
# hacked by jefby,change the output file to /tmp/xxx.tar.bz2
tar --numeric-owner -c . | bzip2 > /tmp/${image}.tar.bz2
cd - >& /dev/null
umount "$mount"
rmdir "$mount"
