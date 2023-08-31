#!/bin/bash -eux

retry() {
  local COUNT=1
  local DELAY=0
  local RESULT=0
  while [[ "${COUNT}" -le 10 ]]; do
    [[ "${RESULT}" -ne 0 ]] && {
      [ "`which tput 2> /dev/null`" != "" ] && [ -n "$TERM" ] && tput setaf 1
      echo -e "\\n${*} failed... retrying ${COUNT} of 10.\\n" >&2
      [ "`which tput 2> /dev/null`" != "" ] && [ -n "$TERM" ] && tput sgr0
    }
    "${@}" && { RESULT=0 && break; } || RESULT="${?}"
    COUNT="$((COUNT + 1))"

    # Increase the delay with each iteration.
    DELAY="$((DELAY + 10))"
    sleep $DELAY
  done

  [[ "${COUNT}" -gt 10 ]] && {
    [ "`which tput 2> /dev/null`" != "" ] && [ -n "$TERM" ] && tput setaf 1
    echo -e "\\nThe command failed 10 times.\\n" >&2
    [ "`which tput 2> /dev/null`" != "" ] && [ -n "$TERM" ] && tput sgr0
  }

  return "${RESULT}"
}

# Download the glibc Alpine packages.
retry apk --no-cache add wget ca-certificates
retry wget -q -O /etc/apk/keys/sgerrand.rsa.pub https://alpine-pkgs.sgerrand.com/sgerrand.rsa.pub

# Unstable.
retry wget --quiet https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.29-r0/glibc-2.29-r0.apk
retry wget --quiet https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.29-r0/glibc-bin-2.29-r0.apk
retry wget --quiet https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.29-r0/glibc-dev-2.29-r0.apk
retry wget --quiet https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.29-r0/glibc-i18n-2.29-r0.apk

# Ensure the compatability library has been removed, to avoid conflicts.
retry apk del libc6-compat

# Install glibc.
retry apk add glibc-2.29-r0.apk glibc-bin-2.29-r0.apk glibc-dev-2.29-r0.apk glibc-i18n-2.29-r0.apk

# Cleanup the apk files.
rm -f glibc-2.29-r0.apk glibc-bin-2.29-r0.apk glibc-dev-2.29-r0.apk glibc-i18n-2.29-r0.apk

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
else
  export PATH=$PATH:/usr/glibc-compat/bin:/usr/glibc-compat/sbin
  export LD_LIBRARY_PATH="/usr/glibc-compat/lib/"
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
