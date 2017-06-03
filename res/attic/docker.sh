#!/bin/bash


export VERSION="0.4.2"
export ATLAS_TOKEN="qyToIsMKMP9P0w.atlasv1.MiyPtcThL0y4Fwk53lFri83nOEt1rUDSQNW2CxFbxJtFd7llvllpqSL176pTkeFVfiE"

LINK=`readlink -f $0`
BASE=`dirname $LINK`
BUILDDATE=$(date +%Y%m%d)

cd $BASE

# Validate the templates before building.
packer validate magma-docker.json
if [[ $? != 0 ]]; then
  printf "\a"; sleep 1; printf "\a"; sleep 1; printf "\a"
  tput setaf 1; tput bold; printf "\n\npacker templates failed to validate...\n\n"; tput sgr0
  exit 1
fi

# Build the virtual machines and extract a file system image for docker.
packer build magma-docker.json
if [[ $? != 0 ]]; then
  rm -rf packer_cache/
  exit 1
fi
exit 0
#
# magma-docker
#
cat << EOF > magma-docker-output/Dockerfile
FROM scratch
MAINTAINER Ladar Levison <ladar@lavabit.com>
LABEL name="Magma Build Image" vendor="Lavabit" license="AGPLv3" build-date="$BUILDDATE" \
  description="The magma encrypted mail daemon build environment." version="$VERSION"
ADD magma-docker-$VERSION.tar.gz /
ENTRYPOINT ["/root/magma-build.sh"]
EOF

TEMPDIR=`mktemp -d`
guestmount -a magma-docker-output/magma-docker -i --ro $TEMPDIR
cd $TEMPDIR
tar --numeric-owner --exclude=/tmp/magma-docker.tar -cz . > $BASE/magma-docker-output/magma-docker-$VERSION.tar.gz
tar --numeric-owner --exclude=/tmp/magma-docker.tar -cz . > $BASE/magma-docker-alt-$VERSION.tar.gz

cd $BASE
guestunmount $TEMPDIR
rm -f magma-docker-output/magma-docker

docker build --force-rm --tag="magma:$VERSION" magma-docker-output

#
# magma-centos6-docker
#
cat << EOF > magma-centos6-docker-output/Dockerfile
FROM scratch
MAINTAINER Ladar Levison <ladar@lavabit.com>
LABEL name="Magma Build Image" vendor="Lavabit" license="AGPLv3" build-date="$BUILDDATE" \
  description="The magma encrypted mail daemon build environment." version="$VERSION"
ADD magma-centos6-docker-$VERSION.tar.gz /
ENTRYPOINT ["/root/magma-build.sh"]
EOF

TEMPDIR=`mktemp -d`
guestmount -a magma-centos6-docker-output/magma-centos6-docker -i --ro $TEMPDIR
cd $TEMPDIR
tar --numeric-owner --exclude=/tmp/magma-docker.tar -cz . > $BASE/magma-centos6-docker-output/magma-centos6-docker-$VERSION.tar.gz
tar --numeric-owner --exclude=/tmp/magma-docker.tar -cz . > $BASE/magma-centos6-docker-alt-$VERSION.tar.gz

cd $BASE
guestunmount $TEMPDIR
rm -f magma-docker-output/magma-centos6-docker

docker build --force-rm --tag="magma-centos6:$VERSION" magma-docker-output

#
# magma-centos7-docker
#
cat << EOF > magma-centos7-docker-output/Dockerfile
FROM scratch
MAINTAINER Ladar Levison <ladar@lavabit.com>
LABEL name="Magma Build Image" vendor="Lavabit" license="AGPLv3" build-date="$BUILDDATE" \
  description="The magma encrypted mail daemon build environment." version="$VERSION"
ADD magma-centos7-docker-$VERSION.tar.gz /
ENTRYPOINT ["/root/magma-build.sh"]
EOF

TEMPDIR=`mktemp -d`
guestmount -a magma-centos7-docker-output/magma-centos7-docker -i --ro $TEMPDIR
cd $TEMPDIR
tar --numeric-owner --exclude=/tmp/magma-docker.tar -cz . > $BASE/magma-centos7-docker-output/magma-centos7-docker-$VERSION.tar.gz
tar --numeric-owner --exclude=/tmp/magma-docker.tar -cz . > $BASE/magma-centos7-docker-alt-$VERSION.tar.gz

cd $BASE
guestunmount $TEMPDIR
rm -f magma-docker-output/magma-centos7-docker

docker build --force-rm --tag="magma-centos7:$VERSION" magma-docker-output

rm -rf packer_cache/ magma-docker-output/ magma-centos6-docker-output/ magma-centos7-docker-output/
