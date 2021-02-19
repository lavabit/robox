#!/bin/bash -eux

retry() {
  local COUNT=1
  local RESULT=0
  while [[ "${COUNT}" -le 10 ]]; do
    [[ "${RESULT}" -ne 0 ]] && {
      [ "`which tput 2> /dev/null`" != "" ] && tput setaf 1
      echo -e "\\n${*} failed... retrying ${COUNT} of 10.\\n" >&2
      [ "`which tput 2> /dev/null`" != "" ] && tput sgr0
    }
    "${@}" && { RESULT=0 && break; } || RESULT="${?}"
    COUNT="$((COUNT + 1))"

    # Increase the delay with each iteration.
    DELAY="$((DELAY + 10))"
    sleep $DELAY
  done

  [[ "${COUNT}" -gt 10 ]] && {
    [ "`which tput 2> /dev/null`" != "" ] && tput setaf 1
    echo -e "\\nThe command failed 10 times.\\n" >&2
    [ "`which tput 2> /dev/null`" != "" ] && tput sgr0
  }

  return "${RESULT}"
}

# The packages needed to compile magma.
retry apk add bash m4 gcc g++ gcc-gnat gdb gdbm grep perl make glib expat \
automake autoconf valgrind binutils binutils-libs gmp isl mpc1 python2 pkgconf \
mpfr3 libtool flex bison cmake ca-certificates patch ncurses-doc ncurses-libs \
ncurses-dev ncurses-static ncurses ncurses-terminfo-base ncurses-terminfo \
makedepend build-base coreutils ctags readline openssl nasm zlib groff subunit \
diffutils doxygen gawk sed texinfo xz jsoncpp subunit-libs \
libc-utils patchutils strace tar kmod bc linux-firmware pcre pcre-tools \
bsd-compat-headers fortify-headers linux-headers curl check fts expect \
linux-vanilla clang clang-libs llvm llvm-static llvm-libs boost \
boost-system boost-thread boost-signals boost-random boost-iostreams tcl \
boost-math boost-serialization boost-filesystem boost-date_time boost-regex \
musl musl-utils npth gpgme \
libbz2 libgomp libatomic libltdl libbsd libattr libacl libarchive libcurl \
libpthread-stubs libgcc libgc++ libressl libaio libuv libxml2 \
libxslt libgc++ libgcj libgnat libstdc++ \
glib-dev libc-dev musl-dev valgrind-dev libbsd-dev subunit-dev \
acl-dev popt-dev python2-dev zlib-dev kmod-dev linux-vanilla-dev \
gmp-dev mpfr-dev libressl-dev readline-dev libaio-dev npth-dev \
util-linux-dev curl-dev expat-dev zlib-dev bzip2-dev libarchive-dev tcl-dev \
libuv-dev xz-dev jsoncpp-dev check-dev pcre-dev fts-dev expect-dev \
libxml2-dev llvm-dev isl-dev clang-dev llvm-dev boost-dev libxslt-dev \
gcc-doc m4-doc make-doc patch-doc

# Need to retrieve the source code.
retry apk add git git-doc git-perl popt rsync wget

# Needed to run the watcher and status scripts.
retry apk add sysstat inotify-tools lm_sensors sysfsutils

# Needed to run the stacie script.
retry apk add py2-crypto py2-cryptography py2-cparser py2-cffi py2-idna py2-asn1 py2-six py2-ipaddress

# Setup the the box. This runs as root
if [ -d /home/vagrant/ ]; then
  OUTPUT="/home/vagrant/magma-build.sh"
else
  OUTPUT="/root/magma-build.sh"
fi

# Grab a snapshot of the development branch.
cat <<-EOF > $OUTPUT
#!/bin/bash

export PATH=/usr/glibc-compat/bin:/usr/glibc-compat/sbin:/usr/bin/:$PATH

error() {
  if [ \$? -ne 0 ]; then
    printf "\n\nmagma daemon compilation failed...\n\n";
    exit 1
  fi
}

if [ -x /usr/bin/id ]; then
  ID=\`/usr/bin/id -u\`
  if [ -n "\$ID" -a "\$ID" -eq 0 ]; then
    rc-service mariadb start
    rc-service postfix start
    rc-service memcached start
  fi
fi

# Temporary [hopefully] workaround to avoid [yet another] bug in NSS.
export NSS_DISABLE_HW_AES=1

# If the TERM environment variable is missing, then tput may trigger a fatal error.
if [[ -n "$TERM" ]] && [[ "$TERM" -ne "dumb" ]]; then
  export TPUT="tput"
else
  export TPUT="tput -Tvt100"
fi

# We need to give the box 30 seconds to get the networking setup or
# the git clone operation will fail.
sleep 30

# If the directory is present, remove it so we can clone a fresh copy.
if [ -d magma-develop ]; then
  rm --recursive --force magma-develop
fi

# Clone the magma repository off Github.
git clone https://github.com/lavabit/magma.git magma-develop; error
cd magma-develop; error

# Setup the bin links, just in case we need to troubleshoot things manually.
dev/scripts/linkup.sh; error

# Compile the dependencies into a shared library.
dev/scripts/builders/build.lib.sh all; error

# Reset the sandbox database and storage files.
dev/scripts/database/schema.reset.sh; error

# Enable the anti-virus engine and update the signatures.
dev/scripts/freshen/freshen.clamav.sh 2>&1 | grep -v WARNING | grep -v PANIC; error
sed -i -e "s/virus.available = false/virus.available = true/g" sandbox/etc/magma.sandbox.config

# Ensure the sandbox config uses port 2525 for relays.
sed -i -e "/magma.relay\[[0-9]*\].name.*/d" sandbox/etc/magma.sandbox.config
sed -i -e "/magma.relay\[[0-9]*\].port.*/d" sandbox/etc/magma.sandbox.config
sed -i -e "/magma.relay\[[0-9]*\].secure.*/d" sandbox/etc/magma.sandbox.config
printf "\n\nmagma.relay[1].name = localhost\nmagma.relay[1].port = 2525\n\n" >> sandbox/etc/magma.sandbox.config

# Bug fix... create the scan directory so ClamAV unit tests work.
if [ ! -d 'sandbox/spool/scan/' ]; then
  mkdir -p sandbox/spool/scan/
fi

# Compile the daemon and then compile the unit tests.
make all; error

# Change the socket path.
sed -i -e "s/\/var\/lib\/mysql\/mysql.sock/\/var\/run\/mysqld\/mysqld.sock/g" sandbox/etc/magma.sandbox.config

# Run the unit tests.
dev/scripts/launch/check.run.sh

# If the unit tests fail, print an error, but contine running.
if [ \$? -ne 0 ]; then
  \${TPUT} setaf 1; \${TPUT} bold; printf "\n\nsome of the magma daemon unit tests failed...\n\n"; \${TPUT} sgr0;
  for i in 1 2 3; do
    printf "\a"; sleep 1
  done
  sleep 12
fi

# Alternatively, run the unit tests atop Valgrind.
# Note this takes awhile when the anti-virus engine is enabled.
# dev/scripts/launch/check.vg

# Daemonize instead of running on the console.
# sed -i -e "s/magma.output.file = false/magma.output.file = true/g" sandbox/etc/magma.sandbox.config
# sed -i -e "s/magma.system.daemonize = false/magma.system.daemonize = true/g" sandbox/etc/magma.sandbox.config

# Launch the daemon.
# ./magmad --config magma.system.daemonize=true sandbox/etc/magma.sandbox.config

# Save the result.
# RETVAL=\$?

# Give the daemon time to start before exiting.
sleep 15

# Exit wit a zero so Vagrant doesn't think a failed unit test is a provision failure.
exit \$RETVAL
EOF

# Make the script executable.
if [ -d /home/vagrant/ ]; then
  chown vagrant:vagrant /home/vagrant/magma-build.sh
  chmod +x /home/vagrant/magma-build.sh
else
  chmod +x /root/magma-build.sh
fi

# Customize the message of the day
printf "Magma Daemon Development Environment\nTo download and compile magma, just execute the magma-build.sh script.\n\n" > /etc/motd
