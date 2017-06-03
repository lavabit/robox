#!/bin/bash -eux

# Download the glibc Alpine packages.
apk --no-cache add wget ca-certificates
wget -q -O /etc/apk/keys/sgerrand.rsa.pub https://raw.githubusercontent.com/sgerrand/alpine-pkg-glibc/master/sgerrand.rsa.pub

# Unstable.
wget --quiet https://github.com/sgerrand/alpine-pkg-glibc/releases/download/unreleased/glibc-2.25-r1.apk
wget --quiet https://github.com/sgerrand/alpine-pkg-glibc/releases/download/unreleased/glibc-bin-2.25-r1.apk
wget --quiet https://github.com/sgerrand/alpine-pkg-glibc/releases/download/unreleased/glibc-dev-2.25-r1.apk
wget --quiet https://github.com/sgerrand/alpine-pkg-glibc/releases/download/unreleased/glibc-i18n-2.25-r1.apk

# Stable but doesn't include the include files.
# wget https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.25-r0/glibc-bin-2.25-r0.apk
# wget https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.25-r0/glibc-2.25-r0.apk
# wget https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.25-r0/glibc-i18n-2.25-r0.apk

# Ensure the compatability library has been removed, to avoid conflicts.
apk del libc6-compat

# Install glibc.
apk add glibc-2.25-r1.apk glibc-bin-2.25-r1.apk glibc-dev-2.25-r1.apk glibc-i18n-2.25-r1.apk

# Cleanup the apk files.
rm -f glibc-2.25-r1.apk glibc-bin-2.25-r1.apk glibc-dev-2.25-r1.apk glibc-i18n-2.25-r1.apk

#  Generate the English/USA locale.
/usr/glibc-compat/bin/localedef -i en_US -f UTF-8 en_US.UTF-8

# Ensure the glibc utilities take precedence for the vagrant user.
cat <<-EOF > /etc/profile.d/glibc.sh
ID=\`/usr/bin/id -u\`
if [ \$ID != 0 ]; then
  export PATH=/usr/glibc-compat/bin:/usr/glibc-compat/sbin:/usr/bin/:$PATH
  export LD_LIBRARY_PATH="/usr/glibc-compat/lib/"
  # export LIBRARY_PATH="/usr/glibc-compat/lib/"
  # export CPATH="/usr/glibc-compat/include/"
  # export C_INCLUDE_PATH="/usr/glibc-compat/include/"
  # export CPLUS_INCLUDE_PATH="/usr/glibc-compat/include/"
  # export OBJC_INCLUDE_PATH="/usr/glibc-compat/include/"
  # export GCC_EXEC_PREFIX="/usr/glibc-compat/"
fi
EOF

# VERSION="2.24"
# PREFIX="/usr/glibc/"
#
# # Install the basic build system utilities.
# apk add --update wget build-base ca-certificates linux-firmware linux-headers \
# linux-virtgrsec linux-virtgrsec-dev util-linux util-linux-bash-completion \
# util-linux-dev util-linux-doc syslinux-dev
#
# # Grab the tarball with the GNU libc source code.
# wget -q -O "glibc-${VERSION}.tar.gz" "http://ftp.gnu.org/gnu/glibc/glibc-${VERSION}.tar.gz"
#
# # Extract the secrets and get ready to rumble.
# tar xzvf glibc-${VERSION}.tar.gz
#
# # The configure script requrires an independent build directory.
# mkdir -p glibc-build && cd glibc-build
#
# ../glibc-${VERSION}/configure --with-headers=/usr/include/linux/ --prefix=/usr/glibc/
#
# # Configure glibc with a prefix so it doesn't conflict with musl.
# ../glibc-${VERSION}/configure --prefix="${PREFIX}" --libdir="${PREFIX}/lib" \
# --libexecdir="${PREFIX}/lib" --enable-multi-arch
#
# # Compile glibc.
# make && make install
