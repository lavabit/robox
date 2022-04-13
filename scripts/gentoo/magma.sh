#!/bin/bash -ux

emerge --ask=n --autounmask-write=y --autounmask-continue=y sys-devel/autoconf sys-devel/gcc sys-devel/flex sys-devel/binutils-config sys-devel/autogen  sys-devel/binutils sys-devel/m4 sys-devel/make sys-devel/libtool sys-devel/automake sys-devel/gettext  sys-devel/bison dev-util/valgrind dev-util/pkgconf sys-libs/readline sys-libs/glibc sys-libs/binutils-libs dev-libs/openssl dev-libs/libevent dev-libs/expat dev-libs/crypto++ dev-libs/check dev-libs/libbsd dev-libs/nspr dev-libs/mpfr dev-libs/mpc dev-libs/libxml2 dev-libs/libxslt dev-libs/shhopt sys-devel/gdb dev-vcs/git dev-vcs/git-tools

# Perform any configuration file updates.
etc-update --automode -5

emerge --ask=n --autounmask-continue=y dev-vcs/git dev-vcs/git-tools

# Perform any configuration file updates.
etc-update --automode -5

# Install MariaDB
emerge --ask=n --autounmask-write=y --autounmask-continue=y dev-db/mariadb

printf "\n\n[mysqld]\nsql-mode=allow_invalid_dates\n" >> /etc/mysql/my.cnf



# export PYTHON_TARGETS="python2_7 python3_3 python3_4 python3_5"
# export PYTHON_SINGLE_TARGET="python2_7"
# export USE="gui client server help network printsupport sql svg webkit opengl egl X"
#

# emerge "~dev-qt/qtcore-4.8.6"

# The packages needed to compile magma.
#  --autounmask-keep-masks
# emerge sys-devel/autoconf sys-devel/gcc sys-devel/flex sys-devel/sparse sys-devel/binutils-config sys-devel/automake-wrapper sys-devel/qconf sys-devel/autogen sys-devel/bc sys-devel/binutils sys-devel/heirloom-devtools sys-devel/llvmgold sys-devel/distcc sys-devel/autoconf-wrapper sys-devel/gcc-config sys-devel/systemd-m4 sys-devel/clang sys-devel/make sys-devel/llvm sys-devel/dev86 sys-devel/pmake sys-devel/libtool sys-devel/lld sys-devel/autoconf-archive sys-devel/native-cctools sys-devel/gnuconfig sys-devel/automake sys-devel/multilib-gcc-wrapper sys-devel/icecream sys-devel/gettext sys-devel/boost-m4 sys-devel/patch sys-devel/ucpp sys-devel/m4 sys-devel/smatch sys-devel/byfl sys-devel/slibtool sys-devel/bin86 sys-devel/bmake sys-devel/ct-ng sys-devel/clang-runtime sys-devel/remake sys-devel/cons sys-devel/bison sys-devel/prelink dev-cpp/libxmlpp dev-cpp/pngpp dev-cpp/libassa dev-cpp/ETL dev-cpp/random123 dev-cpp/yaml-cpp dev-cpp/muParser dev-cpp/gmock dev-cpp/lucene++ dev-cpp/picojson dev-cpp/ctemplate dev-cpp/tbb dev-cpp/catch dev-cpp/cpp-hocon dev-cpp/gccxml dev-cpp/libmcpp dev-cpp/eigen dev-cpp/libbinio dev-cpp/pstreams dev-cpp/libcmis dev-cpp/mm-common dev-cpp/xsd dev-cpp/libxsd-frontend dev-cpp/sparsehash dev-cpp/rudiments dev-cpp/gtest dev-cpp/asio dev-cpp/pficommon dev-cpp/libjson-rpc-cpp dev-cpp/websocketpp dev-cpp/tree dev-cpp/clucene dev-cpp/metslib dev-cpp/tclap dev-cpp/threadpool dev-cpp/antlr-cpp dev-cpp/htmlcxx dev-cpp/commoncpp2 dev-cpp/icnc dev-cpp/libcutl dev-util/bsdiff dev-util/webstorm dev-util/abootimg dev-util/byacc dev-util/repo dev-util/antlrworks dev-util/emilpro dev-util/obs-service-generator_driver_update_disk dev-util/waf dev-util/rustfmt dev-util/cunit dev-util/spec-cleaner dev-util/complexity dev-util/electron dev-util/valgrind dev-util/cflow dev-util/shc dev-util/visualvm dev-util/shflags dev-util/apitrace dev-util/icmake dev-util/omake dev-util/cppunit dev-util/weka dev-util/hxd dev-util/bluej dev-util/rpmdevtools dev-util/yuicompressor dev-util/open-vcdiff dev-util/kelbt dev-util/lttng-tools dev-util/cargo dev-util/vmtouch dev-util/qdevicemonitor dev-util/confix-wrapper dev-util/devhelp dev-util/rats dev-util/obs-service-update_source dev-util/rr dev-util/lxqt-build-tools dev-util/bless dev-util/bam dev-util/pkgconfig-openbsd dev-util/cmake-fedora dev-util/dput-ng dev-util/tinlink dev-util/global dev-util/its4 dev-util/a8 dev-util/qbs dev-util/checkstyle dev-util/pkgconfig dev-util/sasm dev-util/dropwatch dev-util/molecule-core dev-util/d-feet dev-util/osc dev-util/kup dev-util/gengetopt dev-util/obs-service-verify_file dev-util/obs-service-source_validator dev-util/linklint dev-util/trace-cmd dev-util/peg dev-util/wsta dev-util/abi-dumper dev-util/obs-service-download_src_package dev-util/cpuinfo-collection dev-util/cutils dev-util/ald dev-util/hxtools dev-util/autodia dev-util/schroot dev-util/egypt dev-util/indent dev-util/serialtalk dev-util/shelltestrunner dev-util/treecc dev-util/sgb dev-util/setconf dev-util/makeheaders dev-util/wiggle dev-util/vtable-dumper dev-util/sysprof dev-util/synopsis dev-util/ctags dev-util/lcov dev-util/astyle dev-util/cpputest dev-util/flawfinder dev-util/stressapptest dev-util/stubgen dev-util/obs-service-github_tarballs dev-util/memprof dev-util/unifdef dev-util/debootstrap dev-util/idutils dev-util/cppcheck dev-util/debugedit dev-util/catfish dev-util/cpptest dev-util/usb-robot dev-util/pscan dev-util/min-cscope dev-util/findbugs dev-util/oprofile dev-util/colm dev-util/dwdiff dev-util/duma dev-util/btyacc dev-util/bbe dev-util/radare2 dev-util/pkgconf dev-util/quilt dev-util/patchelf dev-util/mutrace dev-util/cligh dev-util/icemon dev-util/cmt dev-util/cppi dev-util/rej dev-util/beediff dev-util/howdoi dev-util/gcovr dev-util/debhelper dev-util/elfkickers dev-util/heaptrack dev-util/babeltrace dev-util/obs-service-download_url dev-util/obs-service-cpanspec dev-util/squashdelta dev-util/ccache dev-util/premake dev-util/lorax dev-util/lockrun dev-util/vbindiff dev-util/uncrustify dev-util/shellcheck dev-util/ragel dev-util/tmake dev-util/sel  dev-util/obs-service-git_tarballs dev-util/diffstat dev-util/cram dev-util/dogtail dev-util/google-perftools dev-util/itstool dev-util/jarwizard dev-util/cmake dev-util/obs-service-extract_file dev-util/dwarves dev-util/obs-service-set_version dev-util/bcc dev-util/bin_replace_string dev-util/creduce dev-util/yacc dev-util/perf dev-util/trinity dev-util/dmake dev-util/fix-la-relink-command dev-util/automoc dev-util/ltrace dev-util/doxy-coverage dev-util/re2c dev-util/boost-build dev-util/cgdb dev-util/imediff2 dev-util/build dev-util/distro-info-data dev-util/obs-service-recompress dev-util/reswrap dev-util/csup dev-util/confix dev-util/lttng-ust dev-util/xmlindent dev-util/bakefile dev-util/pycharm-community dev-util/pretrace dev-util/skipfish dev-util/appinventor dev-util/tailor dev-util/ninja dev-util/igprof dev-util/bitcoin-tx dev-util/aruba dev-util/cmdtest dev-util/txt2regex dev-util/jconfig dev-util/mpatch dev-util/molecule-plugins dev-util/abi-compliance-checker dev-util/docker-ls dev-util/intltool dev-util/gperf dev-util/shunit2 dev-util/makepp dev-util/objconv dev-util/cgvg dev-util/colorgcc dev-util/mdds dev-util/splint dev-util/cscope dev-util/qstlink2 dev-util/vint dev-util/dirdiff dev-util/bustle dev-util/xesam-tools dev-util/cwdiff dev-util/bnfc dev-util/autoproject dev-util/qmtest dev-util/patchutils dev-util/umockdev dev-util/lsuio dev-util/shtool dev-util/strace dev-util/cdiff dev-util/ftjam dev-util/fhist dev-util/lttng-modules dev-util/tkdiff dev-util/cproto dev-util/scons dev-util/ccglue dev-util/cyclo dev-util/molecule dev-util/cccc dev-util/obs-service-download_files dev-util/appdata-tools dev-util/sysdig dev-util/dialog dev-util/leaktracer dev-util/amtterm dev-util/pmd dev-util/crash dev-util/pycharm-professional dev-util/bazel dev-util/dissembler dev-util/edb-debugger dev-util/archdiff dev-util/distro-info dev-util/cloc dev-util/catalyst dev-util/ticpp dev-util/bats dev-util/rbtools dev-util/qfsm dev-util/ply dev-util/difffilter dev-util/argouml dev-util/jay dev-util/smem dev-util/atomic-install dev-util/obs-service-rearchive dev-util/obs-service-meta dev-util/cmocka dev-util/obs-service-format_spec_fil dev-util/obs-service-tar_scm dev-util/systemtap dev-util/valkyrie dev-util/checkbashisms dev-util/bcpp dev-util/comparator dev-util/artifactory-bin dev-util/diffball dev-util/clion dev-util/huc dev-util/rebar dev-util/promu dev-util/App-SVN-Bisect dev-util/fuzz dev-vcs/git dev-vcs/git-tools sys-libs/readline sys-libs/musl sys-libs/glibc sys-libs/binutils-libs dev-libs/openssl dev-libs/libevent dev-libs/libiconv dev-libs/expat dev-libs/crypto++ dev-libs/check dev-libs/boost dev-libs/geoip dev-libs/gmime dev-libs/gnulib dev-libs/jsoncpp dev-libs/libbsd dev-libs/libiconv dev-libs/libmemcached dev-libs/libtasn1 dev-libs/libutf8proc dev-libs/protobuf-c dev-libs/popt dev-libs/nspr dev-libs/mpfr dev-libs/mpc dev-libs/libxml2 dev-libs/libxslt dev-libs/shhopt media-libs/libvpx media-libs/opus =dev-lang/python-2.7.12

# gc gdb-common guile2.0
# Need to retrieve the source code.
# emerge git perl-error

# Needed to run the watcher and status scripts.
# emerge sysstat lm_sensors inotify-tools

# Needed to run the stacie script.
# emerge python-asn1crypto python-cffi python-idna python-ply python-pycparser python-crypto python-cryptography

# Setup the the box. This runs as root
if [ -d /home/vagrant/ ]; then
  OUTPUT="/home/vagrant/magma-build.sh"
else
  OUTPUT="/root/magma-build.sh"
fi

# Grab a snapshot of the development branch.
cat <<-EOF > $OUTPUT
#!/bin/bash

error() {
  if [ \$? -ne 0 ]; then
    printf "\n\nmagma daemon compilation failed...\n\n";
    exit 1
  fi
}

if [ -x /usr/bin/id ]; then
  ID=\`/usr/bin/id -u\`
  if [ -n "\$ID" -a "\$ID" -eq 0 ]; then
    rc-update add mariadb default && rc-service mariadb start
    rc-update add postfix default && rc-service postfix start
    rc-update add memcached default && rc-service memcached start
    # systemctl start mariadb.service
    # systemctl start postfix.service
    # systemctl start memcached.service
  fi
fi

# If the TERM environment variable is missing, then tput may trigger a fatal error.
if [[ -n "\$TERM" ]] && [[ "\$TERM" -ne "dumb" ]]; then
  export TPUT="tput"
else
  export TPUT="tput -Tvt100"
fi

# We need to give the box 30 seconds to get the networking setup or
# the git clone operation will fail.
sleep 30

# Temporary [hopefully] workaround to avoid [yet another] bug in NSS.
export NSS_DISABLE_HW_AES=1

# If the directory is present, remove it so we can clone a fresh copy.
if [ -d magma-develop ]; then
  rm --recursive --force magma-develop
fi

# Clone the magma repository off Github.
git clone --quiet https://github.com/lavabit/magma.git magma-develop && \
  printf "\nMagma repository downloaded\n." ; error
cd magma-develop; error

# Setup the bin links, just in case we need to troubleshoot things manually.
dev/scripts/linkup.sh; error

# Explicitly control the number of build jobs (instead of using nproc).
[ ! -z "\${MAGMA_JOBS##*[!0-9]*}" ] && export M_JOBS="\$MAGMA_JOBS"

# The unit tests for the bundled dependencies get skipped with quick builds.
MAGMA_QUICK=\$(echo \$MAGMA_QUICK | tr "[:lower:]" "[:upper:]")
if [ "\$MAGMA_QUICK" == "YES" ]; then
  export QUICK=yes
fi

# Compile the dependencies into a shared library.
dev/scripts/builders/build.lib.sh all; error

# Reset the sandbox database and storage files.
dev/scripts/database/schema.reset.sh &> lib/logs/schema.txt && \
  printf "\nMagma database schema loaded successfully.\n"; error

# Controls whether ClamAV is enabled, and/or if the signature databases get updated.
MAGMA_CLAMAV=\$(echo \$MAGMA_CLAMAV | tr "[:lower:]" "[:upper:]")
MAGMA_CLAMAV_FRESHEN=\$(echo \$MAGMA_CLAMAV_FRESHEN | tr "[:lower:]" "[:upper:]")
MAGMA_CLAMAV_DOWNLOAD=\$(echo \$MAGMA_CLAMAV_DOWNLOAD | tr "[:lower:]" "[:upper:]")
if [ "\$MAGMA_CLAMAV" == "YES" ]; then
  sed -i 's/^[# ]*magma.iface.virus.available[ ]*=.*$/magma.iface.virus.available = true/g' sandbox/etc/magma.sandbox.config
else
  sed -i 's/^[# ]*magma.iface.virus.available[ ]*=.*$/magma.iface.virus.available = false/g' sandbox/etc/magma.sandbox.config
fi
if [ "\$MAGMA_CLAMAV_DOWNLOAD" == "YES" ]; then
  cd sandbox/virus/ && curl -LOs \
  https://github.com/ladar/clamav-data/raw/main/main.cvd.[01-10] -LOs \
  https://github.com/ladar/clamav-data/raw/main/main.cvd.sha256 -LOs \
  https://github.com/ladar/clamav-data/raw/main/daily.cvd.[01-10] -LOs \
  https://github.com/ladar/clamav-data/raw/main/daily.cvd.sha256 -LOs \
  https://github.com/ladar/clamav-data/raw/main/bytecode.cvd -LOs \
  https://github.com/ladar/clamav-data/raw/main/bytecode.cvd.sha256 && \
  rm -f main.cvd daily.cvd bytecode.cvd && \
  cat main.cvd.01 main.cvd.02 main.cvd.03 main.cvd.04 main.cvd.05 \
  main.cvd.06 main.cvd.07 main.cvd.08 main.cvd.09 main.cvd.10 > main.cvd && \
  cat daily.cvd.01 daily.cvd.02 daily.cvd.03 daily.cvd.04 daily.cvd.05 \
  daily.cvd.06 daily.cvd.07 daily.cvd.08 daily.cvd.09 daily.cvd.10 > daily.cvd && \
  sha256sum -c main.cvd.sha256 daily.cvd.sha256 bytecode.cvd.sha256 && \
  rm -f main.cvd.[01-10] daily.cvd.[01-10] && \
  cd \$HOME/magma-develop
fi
if [ "\$MAGMA_CLAMAV_FRESHEN" == "YES" ]; then
  dev/scripts/freshen/freshen.clamav.sh &> lib/logs/freshen.txt && \
    printf "\nClamAV databases updated.\n"; error
fi

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
make -j4 all &> lib/logs/magma.txt && \
  printf "\nMagma compiled successfully.\n"; error

# Run the unit tests.
dev/scripts/launch/check.run.sh

# If the unit tests fail, print an error, but contine running.
if [ \$? -ne 0 ]; then
  \${TPUT} setaf 1; \${TPUT} bold; printf "\n\nSome of the magma unit tests failed...\n\n"; \${TPUT} sgr0;
  for i in 1 2 3; do
    printf "\a"; sleep 1
  done
  sleep 12
fi

# Alternatively, run the unit tests atop Valgrind.
# Note this takes awhile when the anti-virus engine is enabled.
MAGMA_MEMCHECK=\$(echo \$MAGMA_MEMCHECK | tr "[:lower:]" "[:upper:]")
if [ "\$MAGMA_MEMCHECK" == "YES" ]; then
  dev/scripts/launch/check.vg
fi

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
