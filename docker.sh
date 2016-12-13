#!/bin/bash


VERSION="0.3.7"
export ATLAS_TOKEN="qyToIsMKMP9P0w.atlasv1.MiyPtcThL0y4Fwk53lFri83nOEt1rUDSQNW2CxFbxJtFd7llvllpqSL176pTkeFVfiE"

LINK=`readlink -f $0`
BASE=`dirname $LINK`
BUILDDATE=$(date +%Y%m%d)

cd $BASE

# Build the boxes.
time packer build -var "box_version=$VERSION" magma-docker.json
if [[ $? != 0 ]]; then
  rm -rf packer_cache/                                                      
  exit 1
fi

cat << EOF > magma-docker-output/Dockerfile
FROM scratch
MAINTAINER Ladar Levison <ladar@lavabit.com>
ADD magma-centos6-docker-$VERSION.tar.gz /

LABEL name="Magma Build Image" \\
    vendor="Lavabit" \\
    license="AGPLv3" \\
    build-date="$BUILDDATE"

ENTRYPOINT ["/root/magma-build.sh"]
EOF

TEMPDIR=`mktemp -d`
guestmount -a magma-docker-output/magma-docker -i --ro $TEMPDIR
cd $TEMPDIR
tar --numeric-owner -cz . > $BASE/magma-docker-output/magma-centos6-docker-$VERSION.tar.gz

cd $BASE
guestunmount $TEMPDIR
rm -f magma-docker-output/magma-docker

docker build --force-rm --tag="magma-centos6:$VERSION" magma-docker-output
rm -rf packer_cache/ magma-docker-output/

