#!/bin/bash -eux

VERSION="4.9.4"

LIBITM=true
LIBGCC=true
LIBGOMP=true
LIBATOMIC=true

LANG_CXX=true
LANG_OBJC=true
LANG_JAVA=true

LANG_GO=false
LANG_FORTRAN=false
LANG_ADA=false

export PATH=/usr/glibc-compat/bin:/usr/glibc-compat/sbin:/usr/bin/:/bin:/sbin:/usr/sbin
export LD_LIBRARY_PATH="/usr/glibc-compat/lib/"
export CPATH="/usr/glibc-compat/include/"
export C_INCLUDE_PATH="/usr/glibc-compat/include/"
export CPLUS_INCLUDE_PATH="/usr/glibc-compat/include/"
export OBJC_INCLUDE_PATH="/usr/glibc-compat/include/"
# export GCC_EXEC_PREFIX="/usr/glibc-compat/"

# Download the gcc packages.
apk add wget ca-certificates

# Compilation prerequisites.
apk add bash build-base m4 gcc g++ gcc-gnat libtool flex bison make glib expat automake autoconf \
mpc1 mpc1-doc mpc1-dev nasm nasm-doc mpfr3 mpfr3-doc mpfr-dev gmp gmp-dev gmp-doc \
gawk sed texinfo patchutils grep binutils binutils-libs binutils-dev binutils-gold \
zlib zlib-dev gzip bzip2 tar gettext gettext-lang linux-headers \
gettext-asprintf gperf expect expect-dev tcl tcl-dev ttf-dejavu zip paxmark \
guile guile-dev guile-libs flex flex-dev flex-libs diffutils subversion \
subversion-dev subversion-libs libssh2 libssh2-dev openssh-client isl isl-dev

# Delete this file, as it seems to cause problems.
rm -f /usr/lib/libguile-2.0.so.22.8.1-gdb.scm

# Trigger a linker cache update.
ldconfig

# lbzip2 biblatex dejagnu gettext-static

# Download the tarball.
wget --quiet https://mirrors.kernel.org/gnu/gcc/gcc-${VERSION}/gcc-${VERSION}.tar.gz gcc-${VERSION}.tar.gz

# Uncompress the tarball.
tar xzf gcc-${VERSION}.tar.gz && cd gcc-${VERSION}

# Configure, compile and install.
./configure --disable-multilib && make -j4 && make install

# Cleanup the build directory and remove the tarball.
cd $HOME && rm -rf gcc-${VERSION}.tar.gz gcc-${VERSION}
