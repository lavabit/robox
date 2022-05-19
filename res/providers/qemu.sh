#!/bin/bash -e

# Handle self referencing, sourcing etc.
if [[ $0 != $BASH_SOURCE ]]; then
  export CMD=$BASH_SOURCE
else
  export CMD=$0
fi

# Ensure a consistent working directory so relative paths work.
pushd `dirname $CMD` > /dev/null
BASE=`pwd -P`
popd > /dev/null
cd $BASE

QEMU_VERSION="6.0.1"
QEMU_MD5SUM="10c651469e07844523995e2c980a4fdb"
QEMU_DIR="qemu-${QEMU_VERSION}"
QEMU_ARCHIVE="qemu-${QEMU_VERSION}.tar.xz"
QEMU_URL="https://download.qemu.org/${QEMU_ARCHIVE}"

if grep -q -i "CentOS" /etc/os-release; then
    echo "Installing dependencies for CentOS..."
    sudo yum --assumeyes install \
        glib2-devel \
        ninja-build \
        pixman-devel \
        python3 \
        zlib-devel
else
    echo "Unrecognized host distribution, you are on your own!"
fi

if [ ! -f "${QEMU_ARCHIVE}" ]; then
    echo "${QEMU_ARCHIVE} not found, downloading..."
    curl --output "${QEMU_ARCHIVE}" "${QEMU_URL}"
fi

DOWNLOAD_MD5SUM="$(md5sum "${QEMU_ARCHIVE}" | cut -f1 -d' ')"
if [ "${QEMU_MD5SUM}" != "${DOWNLOAD_MD5SUM}" ]; then
    echo "md5sum of ${QEMU_ARCHIVE} (${DOWNLOAD_MD5SUM}) is not the expected hash (${QEMU_MD5SUM})!"
    rm "${QEMU_ARCHIVE}"
    exit 1
fi

if [ ! -d "${QEMU_DIR}" ]; then
    echo "${QEMU_DIR} not found, extracting from ${QEMU_ARCHIVE}..."
    tar -xf "${QEMU_ARCHIVE}"
fi

pushd "${QEMU_DIR}"
    ./configure \
        --prefix=/usr/local \
        --target-list=i386-softmmu,x86_64-softmmu \
        --without-default-features \
        --enable-kvm \
        --enable-tcg

    make -j${JOBS:-$(nproc)}

    sudo make install
popd

rm -rf "${QEMU_DIR}" "${QEMU_ARCHIVE}"
