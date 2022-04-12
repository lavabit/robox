#!/bin/bash -eux

retry() {
  local COUNT=1
  local RESULT=0
  while [[ "${COUNT}" -le 10 ]]; do
    [[ "${RESULT}" -ne 0 ]] && {
      [ "`which tput 2> /dev/null`" != "" ] && [ -n "$TERM" ] && tput setaf 1
      echo -e "\n${*} failed... retrying ${COUNT} of 10.\n" >&2
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
    echo -e "\nThe command failed 10 times.\n" >&2
    [ "`which tput 2> /dev/null`" != "" ] && [ -n "$TERM" ] && tput sgr0
  }

  return "${RESULT}"
}

# Install the the EPEL repository.
retry yum --assumeyes --enablerepo=extras install epel-release

# Packages needed beyond a minimal install to build and run magma.
retry yum --assumeyes install gdb texinfo autoconf automake libtool ncurses-devel gcc-c++ libstdc++-devel gcc cloog-ppl cpp glibc-devel glibc-headers kernel-headers libgomp mpfr ppl perl perl-Module-Pluggable perl-Pod-Escapes perl-Pod-Simple perl-libs perl-version patch sysstat perl-Time-HiRes cmake libarchive openmpi-devel openmpi procps perl patchutils bison ctags diffstat doxygen elfutils flex gcc-gfortran gettext indent intltool swig cscope byacc zip unzip perl-Digest-HMAC perl-Digest-SHA perl-Digest-SHA1 perl-Digest-Bcrypt perl-Digest-CRC perl-Digest-JHash perl-Digest-MD2 perl-Digest-MD4 perl-Digest-MD5-File perl-Digest-PBKDF2 perl-Digest-Perl-MD5 perl-Digest-SHA3 libgsasl libgsasl-devel expect python java-1.8.0-openjdk wget openssh-clients jq libssh2 libssh2-devel libzstd libzstd-devel libzstd-static stunnel libnghttp2 libnghttp2-devel 

# Install libbsd because DSPAM relies upon for the strl functions, and the
# entropy which improves the availability of random bits, and helps magma
# launch and complete her unit tests faster.
retry yum --assumeyes install libbsd libbsd-devel inotify-tools haveged

# The MySQL services magma relies upon.
retry yum --assumeyes install mysql mysql-server perl-DBI perl-DBD-MySQL

# The memcached services magma uses.
retry yum --assumeyes install libevent memcached

# Packages used to retrieve the magma code, but aren't required for building/running the daemon.
retry yum --assumeyes install wget git rsync perl-Git perl-Error

# Install ClamAV.
retry yum --assumeyes install clamav clamav-data

# Ensure memcached doesn't try to use IPv6.
if [ -f /etc/sysconfig/memcached ]; then
  sed -i "s/[,]\?\:\:1[,]\?//g" /etc/sysconfig/memcached
fi

# Enable and start the daemons.
chkconfig mysqld on
chkconfig memcached on
service mysqld start
service memcached start

# Setup the mysql root account with a random password.
export PRAND=`openssl rand -base64 18`
mysqladmin --user=root password "$PRAND"

# Allow the root user to login to mysql as root by saving the randomly generated password.
printf "\n\n[mysql]\nuser=root\npassword=$PRAND\n\n" >> /root/.my.cnf

# Create the mytool user and grant the required permissions.
mysql --execute="CREATE USER mytool@localhost IDENTIFIED BY 'aComplex1'"
mysql --execute="GRANT ALL ON *.* TO mytool@localhost"

# Install the python packages needed for the stacie script to run, which requires the python cryptography package (installed via pip).
retry yum --assumeyes install zlib-devel openssl-devel libffi-devel python-pip python-ply python-devel python-pycparser python-crypto2.6 libcom_err-devel libsepol-devel libselinux-devel keyutils-libs-devel krb5-devel

# Install the Python Prerequisites
pip install --disable-pip-version-check cryptography==1.5.2 cffi==1.11.5 enum34==1.1.6 idna==2.7 ipaddress==1.0.22 pyasn1==0.4.4 six==1.11.0 setuptools==11.3

printf "export PYTHONPATH=/usr/lib64/python2.6/site-packages/pycrypto-2.6.1-py2.6-linux-x86_64.egg/\n" > /etc/profile.d/pypath.sh
chcon "system_u:object_r:bin_t:s0" /etc/profile.d/pypath.sh
chmod 644 /etc/profile.d/pypath.sh

cat <<-EOF > /etc/security/limits.d/25-root.conf
root    soft    memlock    2027044
root    hard    memlock    2027044
root    soft    stack      2027044
root    hard    stack      2027044
root    soft    nofile     1048576
root    hard    nofile     1048576
root    soft    nproc      65536
root    hard    nproc      65536
EOF

cat <<-EOF > /etc/security/limits.d/90-everybody.conf
*    soft    memlock    2027044
*    hard    memlock    2027044
*    soft    stack      unlimited
*    hard    stack      unlimited
*    soft    nofile     65536
*    hard    nofile     65536
*    soft    nproc      65536
*    hard    nproc      65536
EOF

chmod 644 /etc/security/limits.d/25-root.conf
chmod 644 /etc/security/limits.d/90-everybody.conf
chcon "system_u:object_r:etc_t:s0" /etc/security/limits.d/25-root.conf
chcon "system_u:object_r:etc_t:s0" /etc/security/limits.d/90-everybody.conf

# Create the clamav user to avoid spurious errors when compilintg ClamAV.
useradd clamav && usermod --lock --shell /sbin/nologin clamav

# Build and install Valgrind.
cd $HOME
curl -Lo valgrind-3.15.0.tar.bz2 https://sourceware.org/pub/valgrind/valgrind-3.15.0.tar.bz2
echo "417c7a9da8f60dd05698b3a7bc6002e4ef996f14c13f0ff96679a16873e78ab1  valgrind-3.15.0.tar.bz2" | sha256sum -c || exit 1
tar xjvf valgrind-3.15.0.tar.bz2 && cd valgrind-3.15.0
patch -p1 --fuzz=0 <<-EOF
diff --git a/Makefile.all.am b/Makefile.all.am
index 3786e34..1befef5 100644
--- a/Makefile.all.am
+++ b/Makefile.all.am
@@ -50,20 +50,20 @@ inplace-noinst_DSYMS: build-noinst_DSYMS
 	done
 
 # This is used by coregrind/Makefile.am and by <tool>/Makefile.am for doing
-# "make install".  It copies \$(noinst_PROGRAMS) into \$prefix/lib/valgrind/.
+# "make install".  It copies \$(noinst_PROGRAMS) into \$prefix/libexec/valgrind/.
 # It needs to be depended on by an 'install-exec-local' rule.
 install-noinst_PROGRAMS: \$(noinst_PROGRAMS)
-	\$(mkinstalldirs) \$(DESTDIR)\$(pkglibdir); \\
+	\$(mkinstalldirs) \$(DESTDIR)\$(pkglibexecdir); \\
 	for f in \$(noinst_PROGRAMS); do \\
-	  \$(INSTALL_PROGRAM) \$\$f \$(DESTDIR)\$(pkglibdir); \\
+	  \$(INSTALL_PROGRAM) \$\$f \$(DESTDIR)\$(pkglibexecdir); \\
 	done
 
 # This is used by coregrind/Makefile.am and by <tool>/Makefile.am for doing
-# "make uninstall".  It removes \$(noinst_PROGRAMS) from \$prefix/lib/valgrind/.
+# "make uninstall".  It removes \$(noinst_PROGRAMS) from \$prefix/libexec/valgrind/.
 # It needs to be depended on by an 'uninstall-local' rule.
 uninstall-noinst_PROGRAMS:
 	for f in \$(noinst_PROGRAMS); do \\
-	  rm -f \$(DESTDIR)\$(pkglibdir)/\$\$f; \\
+	  rm -f \$(DESTDIR)\$(pkglibexecdir)/\$\$f; \\
 	done
 
 # Similar to install-noinst_PROGRAMS.
@@ -71,15 +71,15 @@ uninstall-noinst_PROGRAMS:
 # directories.  XXX: not sure whether the resulting permissions will be
 # correct when using 'cp -R'...
 install-noinst_DSYMS: build-noinst_DSYMS
-	\$(mkinstalldirs) \$(DESTDIR)\$(pkglibdir); \\
+	\$(mkinstalldirs) \$(DESTDIR)\$(pkglibexecdir); \\
 	for f in \$(noinst_DSYMS); do \\
-	  cp -R \$\$f.dSYM \$(DESTDIR)\$(pkglibdir); \\
+	  cp -R \$\$f.dSYM \$(DESTDIR)\$(pkglibexecdir); \\
 	done
 
 # Similar to uninstall-noinst_PROGRAMS.
 uninstall-noinst_DSYMS:
 	for f in \$(noinst_DSYMS); do \\
-	  rm -f \$(DESTDIR)\$(pkglibdir)/\$\$f.dSYM; \\
+	  rm -f \$(DESTDIR)\$(pkglibexecdir)/\$\$f.dSYM; \\
 	done
 
 # This needs to be depended on by a 'clean-local' rule.
diff --git a/Makefile.am b/Makefile.am
index 242b38a..3b7c806 100644
--- a/Makefile.am
+++ b/Makefile.am
@@ -58,7 +58,7 @@ DEFAULT_SUPP_FILES = @DEFAULT_SUPP@
 # default.supp, as it is built from the base .supp files at compile-time.
 dist_noinst_DATA = \$(SUPP_FILES)
 
-vglibdir = \$(pkglibdir)
+vglibdir = \$(pkglibexecdir)
 vglib_DATA = default.supp
 
 pkgconfigdir = \$(libdir)/pkgconfig
diff --git a/VEX/priv/guest_amd64_defs.h b/VEX/priv/guest_amd64_defs.h
index 169b122..e10f391 100644
--- a/VEX/priv/guest_amd64_defs.h
+++ b/VEX/priv/guest_amd64_defs.h
@@ -167,7 +167,9 @@ extern void  amd64g_dirtyhelper_storeF80le ( Addr/*addr*/, ULong/*data*/ );
 extern void  amd64g_dirtyhelper_CPUID_baseline ( VexGuestAMD64State* st );
 extern void  amd64g_dirtyhelper_CPUID_sse3_and_cx16 ( VexGuestAMD64State* st );
 extern void  amd64g_dirtyhelper_CPUID_sse42_and_cx16 ( VexGuestAMD64State* st );
-extern void  amd64g_dirtyhelper_CPUID_avx_and_cx16 ( VexGuestAMD64State* st );
+extern void  amd64g_dirtyhelper_CPUID_avx_and_cx16 ( VexGuestAMD64State* st,
+                                                     ULong hasF16C,
+                                                     ULong hasRDRAND );
 extern void  amd64g_dirtyhelper_CPUID_avx2 ( VexGuestAMD64State* st,
                                              ULong hasF16C, ULong hasRDRAND );
 
diff --git a/VEX/priv/guest_amd64_helpers.c b/VEX/priv/guest_amd64_helpers.c
index c7a0719..884184a 100644
--- a/VEX/priv/guest_amd64_helpers.c
+++ b/VEX/priv/guest_amd64_helpers.c
@@ -3143,8 +3143,11 @@ void amd64g_dirtyhelper_CPUID_sse42_and_cx16 ( VexGuestAMD64State* st )
    address sizes   : 36 bits physical, 48 bits virtual
    power management:
 */
-void amd64g_dirtyhelper_CPUID_avx_and_cx16 ( VexGuestAMD64State* st )
+void amd64g_dirtyhelper_CPUID_avx_and_cx16 ( VexGuestAMD64State* st,
+                                             ULong hasF16C, ULong hasRDRAND )
 {
+   vassert((hasF16C >> 1) == 0ULL);
+   vassert((hasRDRAND >> 1) == 0ULL);
 #  define SET_ABCD(_a,_b,_c,_d)                \\
       do { st->guest_RAX = (ULong)(_a);        \\
            st->guest_RBX = (ULong)(_b);        \\
@@ -3159,9 +3162,14 @@ void amd64g_dirtyhelper_CPUID_avx_and_cx16 ( VexGuestAMD64State* st )
       case 0x00000000:
          SET_ABCD(0x0000000d, 0x756e6547, 0x6c65746e, 0x49656e69);
          break;
-      case 0x00000001:
-         SET_ABCD(0x000206a7, 0x00100800, 0x1f9ae3bf, 0xbfebfbff);
+      case 0x00000001: {
+         // As a baseline, advertise neither F16C (ecx:29) nor RDRAND (ecx:30),
+         // but patch in support for them as directed by the caller.
+         UInt ecx_extra
+            = (hasF16C ? (1U << 29) : 0) | (hasRDRAND ? (1U << 30) : 0);
+         SET_ABCD(0x000206a7, 0x00100800, (0x1f9ae3bf | ecx_extra), 0xbfebfbff);
          break;
+      }
       case 0x00000002:
          SET_ABCD(0x76035a01, 0x00f0b0ff, 0x00000000, 0x00ca0000);
          break;
diff --git a/VEX/priv/guest_amd64_toIR.c b/VEX/priv/guest_amd64_toIR.c
index 7a20d45..f1edc58 100644
--- a/VEX/priv/guest_amd64_toIR.c
+++ b/VEX/priv/guest_amd64_toIR.c
@@ -22009,7 +22009,8 @@ Long dis_ESC_0F (
 
       vassert(fName); vassert(fAddr);
       IRExpr** args = NULL;
-      if (fAddr == &amd64g_dirtyhelper_CPUID_avx2) {
+      if (fAddr == &amd64g_dirtyhelper_CPUID_avx2
+          || fAddr == &amd64g_dirtyhelper_CPUID_avx_and_cx16) {
          Bool hasF16C   = (archinfo->hwcaps & VEX_HWCAPS_AMD64_F16C) != 0;
          Bool hasRDRAND = (archinfo->hwcaps & VEX_HWCAPS_AMD64_RDRAND) != 0;
          args = mkIRExprVec_3(IRExpr_GSPTR(),
diff --git a/VEX/priv/guest_s390_helpers.c b/VEX/priv/guest_s390_helpers.c
index 5877743..1077437 100644
--- a/VEX/priv/guest_s390_helpers.c
+++ b/VEX/priv/guest_s390_helpers.c
@@ -2469,7 +2469,7 @@ missed:
 /*--- Dirty helper for vector instructions                 ---*/
 /*------------------------------------------------------------*/
 
-#if defined(VGA_s390x)
+#if defined(VGA_s390x) && 0 /* disable for old binutils */
 ULong
 s390x_dirtyhelper_vec_op(VexGuestS390XState *guest_state,
                          const ULong serialized)
diff --git a/cachegrind/cg_sim.c b/cachegrind/cg_sim.c
index 7a8b3bf..05e13e0 100644
--- a/cachegrind/cg_sim.c
+++ b/cachegrind/cg_sim.c
@@ -42,27 +42,30 @@ typedef struct {
    Int          size;                   /* bytes */
    Int          assoc;
    Int          line_size;              /* bytes */
-   Int          sets;
    Int          sets_min_1;
    Int          line_size_bits;
    Int          tag_shift;
-   HChar        desc_line[128];         /* large enough */
    UWord*       tags;
-} cache_t2;
+   HChar        desc_line[128];
+} cache_t2
+#ifdef __GNUC__
+__attribute__ ((aligned (8 * sizeof (Int))))
+#endif
+;
 
 /* By this point, the size/assoc/line_size has been checked. */
 static void cachesim_initcache(cache_t config, cache_t2* c)
 {
-   Int i;
+   Int sets;
 
    c->size      = config.size;
    c->assoc     = config.assoc;
    c->line_size = config.line_size;
 
-   c->sets           = (c->size / c->line_size) / c->assoc;
-   c->sets_min_1     = c->sets - 1;
+   sets              = (c->size / c->line_size) / c->assoc;
+   c->sets_min_1     = sets - 1;
    c->line_size_bits = VG_(log2)(c->line_size);
-   c->tag_shift      = c->line_size_bits + VG_(log2)(c->sets);
+   c->tag_shift      = c->line_size_bits + VG_(log2)(sets);
 
    if (c->assoc == 1) {
       VG_(sprintf)(c->desc_line, "%d B, %d B, direct-mapped", 
@@ -72,11 +75,8 @@ static void cachesim_initcache(cache_t config, cache_t2* c)
                                  c->size, c->line_size, c->assoc);
    }
 
-   c->tags = VG_(malloc)("cg.sim.ci.1",
-                         sizeof(UWord) * c->sets * c->assoc);
-
-   for (i = 0; i < c->sets * c->assoc; i++)
-      c->tags[i] = 0;
+   c->tags = VG_(calloc)("cg.sim.ci.1",
+                         sizeof(UWord), sets * c->assoc);
 }
 
 /* This attribute forces GCC to inline the function, getting rid of a
diff --git a/configure.ac b/configure.ac
index f8c798b..e496a99 100755
--- a/configure.ac
+++ b/configure.ac
@@ -4172,6 +4172,7 @@ AC_CHECK_FUNCS([     \\
         utimensat    \\
         process_vm_readv  \\
         process_vm_writev \\
+        copy_file_range \\
         ])
 
 # AC_CHECK_LIB adds any library found to the variable LIBS, and links these
@@ -4187,6 +4188,8 @@ AM_CONDITIONAL([HAVE_PTHREAD_SPINLOCK],
                [test x\$ac_cv_func_pthread_spin_lock = xyes])
 AM_CONDITIONAL([HAVE_PTHREAD_SETNAME_NP],
                [test x\$ac_cv_func_pthread_setname_np = xyes])
+AM_CONDITIONAL([HAVE_COPY_FILE_RANGE],
+               [test x\$ac_cv_func_copy_file_range = xyes])
 
 if test x\$VGCONF_PLATFORM_PRI_CAPS = xMIPS32_LINUX \\
      -o x\$VGCONF_PLATFORM_PRI_CAPS = xMIPS64_LINUX ; then
diff --git a/coregrind/Makefile.am b/coregrind/Makefile.am
index 94030fd..f09763a 100644
--- a/coregrind/Makefile.am
+++ b/coregrind/Makefile.am
@@ -11,12 +11,12 @@ include \$(top_srcdir)/Makefile.all.am
 
 AM_CPPFLAGS_@VGCONF_PLATFORM_PRI_CAPS@ += \\
 	-I\$(top_srcdir)/coregrind \\
-	-DVG_LIBDIR="\\"\$(pkglibdir)"\\" \\
+	-DVG_LIBDIR="\\"\$(pkglibexecdir)"\\" \\
 	-DVG_PLATFORM="\\"@VGCONF_ARCH_PRI@-@VGCONF_OS@\\""
 if VGCONF_HAVE_PLATFORM_SEC
 AM_CPPFLAGS_@VGCONF_PLATFORM_SEC_CAPS@ += \\
 	-I\$(top_srcdir)/coregrind \\
-	-DVG_LIBDIR="\\"\$(pkglibdir)"\\" \\
+	-DVG_LIBDIR="\\"\$(pkglibexecdir)"\\" \\
 	-DVG_PLATFORM="\\"@VGCONF_ARCH_SEC@-@VGCONF_OS@\\""
 endif
 
@@ -714,7 +714,7 @@ GDBSERVER_XML_FILES = \\
 	m_gdbserver/mips64-fpu.xml
 
 # so as to make sure these get copied into the install tree
-vglibdir = \$(pkglibdir)
+vglibdir = \$(pkglibexecdir)
 vglib_DATA  = \$(GDBSERVER_XML_FILES)
 
 # so as to make sure these get copied into the tarball
diff --git a/coregrind/m_machine.c b/coregrind/m_machine.c
index df842aa..401bd9f 100644
--- a/coregrind/m_machine.c
+++ b/coregrind/m_machine.c
@@ -1078,10 +1078,10 @@ Bool VG_(machine_get_hwcaps)( void )
         have_avx2 = (ebx & (1<<5)) != 0; /* True => have AVX2 */
      }
 
-     /* Sanity check for RDRAND and F16C.  These don't actually *need* AVX2, but
-        it's convenient to restrict them to the AVX2 case since the simulated
-        CPUID we'll offer them on has AVX2 as a base. */
-     if (!have_avx2) {
+     /* Sanity check for RDRAND and F16C.  These don't actually *need* AVX, but
+        it's convenient to restrict them to the AVX case since the simulated
+        CPUID we'll offer them on has AVX as a base. */
+     if (!have_avx) {
         have_f16c   = False;
         have_rdrand = False;
      }
diff --git a/coregrind/m_syswrap/priv_syswrap-generic.h b/coregrind/m_syswrap/priv_syswrap-generic.h
index 66c8c40..96e0bab 100644
--- a/coregrind/m_syswrap/priv_syswrap-generic.h
+++ b/coregrind/m_syswrap/priv_syswrap-generic.h
@@ -108,6 +108,10 @@ extern Bool
 ML_(handle_auxv_open)(SyscallStatus *status, const HChar *filename,
                       int flags);
 
+/* Helper function for generic mprotect and linux pkey_mprotect. */
+extern void handle_sys_mprotect (ThreadId tid, SyscallStatus *status,
+                                 Addr *addr, SizeT *len, Int *prot);
+
 DECL_TEMPLATE(generic, sys_ni_syscall);            // * P -- unimplemented
 DECL_TEMPLATE(generic, sys_exit);
 DECL_TEMPLATE(generic, sys_fork);
diff --git a/coregrind/m_syswrap/priv_syswrap-linux.h b/coregrind/m_syswrap/priv_syswrap-linux.h
index f76191a..388b50e 100644
--- a/coregrind/m_syswrap/priv_syswrap-linux.h
+++ b/coregrind/m_syswrap/priv_syswrap-linux.h
@@ -301,6 +301,11 @@ DECL_TEMPLATE(linux, sys_bpf);
 // Linux-specific (new in Linux 4.11)
 DECL_TEMPLATE(linux, sys_statx);
 
+// Linux-specific memory protection key syscalls (since Linux 4.9)
+DECL_TEMPLATE(linux, sys_pkey_alloc);
+DECL_TEMPLATE(linux, sys_pkey_free);
+DECL_TEMPLATE(linux, sys_pkey_mprotect);
+
 /* ---------------------------------------------------------------------
    Wrappers for sockets and ipc-ery.  These are split into standalone
    procedures because x86-linux hides them inside multiplexors
@@ -379,6 +384,7 @@ DECL_TEMPLATE(linux, sys_getsockname);
 DECL_TEMPLATE(linux, sys_getpeername);
 DECL_TEMPLATE(linux, sys_socketpair);
 DECL_TEMPLATE(linux, sys_kcmp);
+DECL_TEMPLATE(linux, sys_copy_file_range);
 
 // Some arch specific functions called from syswrap-linux.c
 extern Int do_syscall_clone_x86_linux ( Word (*fn)(void *), 
diff --git a/coregrind/m_syswrap/syswrap-amd64-linux.c b/coregrind/m_syswrap/syswrap-amd64-linux.c
index 30e7d0e..9550159 100644
--- a/coregrind/m_syswrap/syswrap-amd64-linux.c
+++ b/coregrind/m_syswrap/syswrap-amd64-linux.c
@@ -863,6 +863,12 @@ static SyscallTableEntry syscall_table[] = {
    LINXY(__NR_statx,             sys_statx),             // 332
 
    LINX_(__NR_membarrier,        sys_membarrier),        // 324
+
+   LINX_(__NR_copy_file_range,   sys_copy_file_range),   // 326
+
+   LINXY(__NR_pkey_mprotect,     sys_pkey_mprotect),     // 329
+   LINX_(__NR_pkey_alloc,        sys_pkey_alloc),        // 330
+   LINX_(__NR_pkey_free,         sys_pkey_free),         // 331
 };
 
 SyscallTableEntry* ML_(get_linux_syscall_entry) ( UInt sysno )
diff --git a/coregrind/m_syswrap/syswrap-arm-linux.c b/coregrind/m_syswrap/syswrap-arm-linux.c
index 9f1bdab..9ba0665 100644
--- a/coregrind/m_syswrap/syswrap-arm-linux.c
+++ b/coregrind/m_syswrap/syswrap-arm-linux.c
@@ -1016,6 +1016,8 @@ static SyscallTableEntry syscall_main_table[] = {
    LINXY(__NR_getrandom,         sys_getrandom),        // 384
    LINXY(__NR_memfd_create,      sys_memfd_create),     // 385
 
+   LINX_(__NR_copy_file_range,   sys_copy_file_range),  // 391
+
    LINXY(__NR_statx,             sys_statx),            // 397
 };
 
diff --git a/coregrind/m_syswrap/syswrap-arm64-linux.c b/coregrind/m_syswrap/syswrap-arm64-linux.c
index 290320a..f66be2d 100644
--- a/coregrind/m_syswrap/syswrap-arm64-linux.c
+++ b/coregrind/m_syswrap/syswrap-arm64-linux.c
@@ -819,7 +819,7 @@ static SyscallTableEntry syscall_main_table[] = {
    //   (__NR_userfaultfd,       sys_ni_syscall),        // 282
    LINX_(__NR_membarrier,        sys_membarrier),        // 283
    //   (__NR_mlock2,            sys_ni_syscall),        // 284
-   //   (__NR_copy_file_range,   sys_ni_syscall),        // 285
+   LINX_(__NR_copy_file_range,   sys_copy_file_range),   // 285
    //   (__NR_preadv2,           sys_ni_syscall),        // 286
    //   (__NR_pwritev2,          sys_ni_syscall),        // 287
    //   (__NR_pkey_mprotect,     sys_ni_syscall),        // 288
diff --git a/coregrind/m_syswrap/syswrap-generic.c b/coregrind/m_syswrap/syswrap-generic.c
index 8b3d6fc..a0e2948 100644
--- a/coregrind/m_syswrap/syswrap-generic.c
+++ b/coregrind/m_syswrap/syswrap-generic.c
@@ -3844,12 +3844,28 @@ PRE(sys_mprotect)
    PRE_REG_READ3(long, "mprotect",
                  unsigned long, addr, vki_size_t, len, unsigned long, prot);
 
-   if (!ML_(valid_client_addr)(ARG1, ARG2, tid, "mprotect")) {
+   Addr addr = ARG1;
+   SizeT len = ARG2;
+   Int prot  = ARG3;
+
+   handle_sys_mprotect (tid, status, &addr, &len, &prot);
+
+   ARG1 = addr;
+   ARG2 = len;
+   ARG3 = prot;
+}
+/* This will be called from the generic mprotect, or the linux specific
+   pkey_mprotect. Pass pointers to ARG1, ARG2 and ARG3 as addr, len and prot,
+   they might be adjusted and have to assigned back to ARG1, ARG2 and ARG3.  */
+void handle_sys_mprotect(ThreadId tid, SyscallStatus* status,
+                         Addr *addr, SizeT *len, Int *prot)
+{
+   if (!ML_(valid_client_addr)(*addr, *len, tid, "mprotect")) {
       SET_STATUS_Failure( VKI_ENOMEM );
    } 
 #if defined(VKI_PROT_GROWSDOWN)
    else 
-   if (ARG3 & (VKI_PROT_GROWSDOWN|VKI_PROT_GROWSUP)) {
+   if (*prot & (VKI_PROT_GROWSDOWN|VKI_PROT_GROWSUP)) {
       /* Deal with mprotects on growable stack areas.
 
          The critical files to understand all this are mm/mprotect.c
@@ -3864,8 +3880,8 @@ PRE(sys_mprotect)
 
          The sanity check provided by the kernel is that the vma must
          have the VM_GROWSDOWN/VM_GROWSUP flag set as appropriate.  */
-      UInt grows = ARG3 & (VKI_PROT_GROWSDOWN|VKI_PROT_GROWSUP);
-      NSegment const *aseg = VG_(am_find_nsegment)(ARG1);
+      UInt grows = *prot & (VKI_PROT_GROWSDOWN|VKI_PROT_GROWSUP);
+      NSegment const *aseg = VG_(am_find_nsegment)(*addr);
       NSegment const *rseg;
 
       vg_assert(aseg);
@@ -3876,10 +3892,10 @@ PRE(sys_mprotect)
              && rseg->kind == SkResvn
              && rseg->smode == SmUpper
              && rseg->end+1 == aseg->start) {
-            Addr end = ARG1 + ARG2;
-            ARG1 = aseg->start;
-            ARG2 = end - aseg->start;
-            ARG3 &= ~VKI_PROT_GROWSDOWN;
+            Addr end = *addr + *len;
+            *addr = aseg->start;
+            *len = end - aseg->start;
+            *prot &= ~VKI_PROT_GROWSDOWN;
          } else {
             SET_STATUS_Failure( VKI_EINVAL );
          }
@@ -3889,8 +3905,8 @@ PRE(sys_mprotect)
              && rseg->kind == SkResvn
              && rseg->smode == SmLower
              && aseg->end+1 == rseg->start) {
-            ARG2 = aseg->end - ARG1 + 1;
-            ARG3 &= ~VKI_PROT_GROWSUP;
+            *len = aseg->end - *addr + 1;
+            *prot &= ~VKI_PROT_GROWSUP;
          } else {
             SET_STATUS_Failure( VKI_EINVAL );
          }
diff --git a/coregrind/m_syswrap/syswrap-linux.c b/coregrind/m_syswrap/syswrap-linux.c
index 73ef98d..95fc90b 100644
--- a/coregrind/m_syswrap/syswrap-linux.c
+++ b/coregrind/m_syswrap/syswrap-linux.c
@@ -12093,6 +12093,106 @@ POST(sys_bpf)
    }
 }
 
+PRE(sys_copy_file_range)
+{
+  PRINT("sys_copy_file_range (%lu, %lu, %lu, %lu, %lu, %lu)", ARG1, ARG2, ARG3,
+        ARG4, ARG5, ARG6);
+
+  PRE_REG_READ6(vki_size_t, "copy_file_range",
+                int, "fd_in",
+                vki_loff_t *, "off_in",
+                int, "fd_out",
+                vki_loff_t *, "off_out",
+                vki_size_t, "len",
+                unsigned int, "flags");
+
+  /* File descriptors are "specially" tracked by valgrind.
+     valgrind itself uses some, so make sure someone didn't
+     put in one of our own...  */
+  if (!ML_(fd_allowed)(ARG1, "copy_file_range(fd_in)", tid, False) ||
+      !ML_(fd_allowed)(ARG3, "copy_file_range(fd_in)", tid, False)) {
+     SET_STATUS_Failure( VKI_EBADF );
+  } else {
+     /* Now see if the offsets are defined. PRE_MEM_READ will
+        double check it can dereference them. */
+     if (ARG2 != 0)
+        PRE_MEM_READ( "copy_file_range(off_in)", ARG2, sizeof(vki_loff_t));
+     if (ARG4 != 0)
+        PRE_MEM_READ( "copy_file_range(off_out)", ARG4, sizeof(vki_loff_t));
+  }
+}
+
+PRE(sys_pkey_alloc)
+{
+  PRINT("pkey_alloc (%lu, %lu)", ARG1, ARG2);
+
+  PRE_REG_READ2(long, "pkey_alloc",
+                unsigned long, "flags",
+                unsigned long, "access_rights");
+
+  /* The kernel says: pkey_alloc() is always safe to call regardless of
+     whether or not the operating system supports protection keys.  It can be
+     used in lieu of any other mechanism for detecting pkey support and will
+     simply fail with the error ENOSPC if the operating system has no pkey
+     support.
+
+     So we simply always return ENOSPC to signal memory protection keys are
+     not supported under valgrind, unless there are unknown flags, then we
+     return EINVAL. */
+  unsigned long pkey_flags = ARG1;
+  if (pkey_flags != 0)
+     SET_STATUS_Failure( VKI_EINVAL );
+  else
+     SET_STATUS_Failure( VKI_ENOSPC );
+}
+
+PRE(sys_pkey_free)
+{
+  PRINT("pkey_free (%" FMT_REGWORD "u )", ARG1);
+
+  PRE_REG_READ1(long, "pkey_free",
+                unsigned long, "pkey");
+
+  /* Since pkey_alloc () can never succeed, see above, freeing any pkey is
+     always an error.  */
+  SET_STATUS_Failure( VKI_EINVAL );
+}
+
+PRE(sys_pkey_mprotect)
+{
+   PRINT("sys_pkey_mprotect ( %#" FMT_REGWORD "x, %" FMT_REGWORD "u, %"
+         FMT_REGWORD "u %" FMT_REGWORD "u )", ARG1, ARG2, ARG3, ARG4);
+   PRE_REG_READ4(long, "pkey_mprotect",
+                 unsigned long, addr, vki_size_t, len, unsigned long, prot,
+                 unsigned long, pkey);
+
+   Addr  addr = ARG1;
+   SizeT len  = ARG2;
+   Int   prot = ARG3;
+   Int   pkey = ARG4;
+
+   /* Since pkey_alloc () can never succeed, see above, any pkey is
+      invalid. Except for -1, then pkey_mprotect acts just like mprotect.  */
+   if (pkey != -1)
+      SET_STATUS_Failure( VKI_EINVAL );
+   else
+      handle_sys_mprotect (tid, status, &addr, &len, &prot);
+
+   ARG1 = addr;
+   ARG2 = len;
+   ARG3 = prot;
+}
+
+POST(sys_pkey_mprotect)
+{
+   Addr  addr = ARG1;
+   SizeT len  = ARG2;
+   Int   prot = ARG3;
+
+   ML_(notify_core_and_tool_of_mprotect)(addr, len, prot);
+}
+
+
 #undef PRE
 #undef POST
 
diff --git a/coregrind/m_syswrap/syswrap-ppc32-linux.c b/coregrind/m_syswrap/syswrap-ppc32-linux.c
index f812f1f..71f208d 100644
--- a/coregrind/m_syswrap/syswrap-ppc32-linux.c
+++ b/coregrind/m_syswrap/syswrap-ppc32-linux.c
@@ -1021,6 +1021,8 @@ static SyscallTableEntry syscall_table[] = {
    LINXY(__NR_getrandom,         sys_getrandom),        // 359
    LINXY(__NR_memfd_create,      sys_memfd_create),     // 360
 
+   LINX_(__NR_copy_file_range,   sys_copy_file_range),  // 379
+
    LINXY(__NR_statx,             sys_statx),            // 383
 };
 
diff --git a/coregrind/m_syswrap/syswrap-ppc64-linux.c b/coregrind/m_syswrap/syswrap-ppc64-linux.c
index eada099..1a42c1f 100644
--- a/coregrind/m_syswrap/syswrap-ppc64-linux.c
+++ b/coregrind/m_syswrap/syswrap-ppc64-linux.c
@@ -1007,6 +1007,8 @@ static SyscallTableEntry syscall_table[] = {
 
    LINX_(__NR_membarrier,        sys_membarrier),       // 365
 
+   LINX_(__NR_copy_file_range,   sys_copy_file_range),  // 379
+
    LINXY(__NR_statx,             sys_statx),            // 383
 };
 
diff --git a/coregrind/m_syswrap/syswrap-s390x-linux.c b/coregrind/m_syswrap/syswrap-s390x-linux.c
index ad78384..41ada8d 100644
--- a/coregrind/m_syswrap/syswrap-s390x-linux.c
+++ b/coregrind/m_syswrap/syswrap-s390x-linux.c
@@ -854,6 +854,8 @@ static SyscallTableEntry syscall_table[] = {
    LINXY(__NR_recvmsg, sys_recvmsg),                                  // 372
    LINX_(__NR_shutdown, sys_shutdown),                                // 373
 
+   LINX_(__NR_copy_file_range, sys_copy_file_range),                  // 375
+
    LINXY(__NR_statx, sys_statx),                                      // 379
 };
 
diff --git a/coregrind/m_syswrap/syswrap-x86-linux.c b/coregrind/m_syswrap/syswrap-x86-linux.c
index f05619e..8205720 100644
--- a/coregrind/m_syswrap/syswrap-x86-linux.c
+++ b/coregrind/m_syswrap/syswrap-x86-linux.c
@@ -1608,6 +1608,11 @@ static SyscallTableEntry syscall_table[] = {
 
    LINX_(__NR_membarrier,        sys_membarrier),       // 375
 
+   LINX_(__NR_copy_file_range,   sys_copy_file_range),   // 377
+
+   LINXY(__NR_pkey_mprotect,     sys_pkey_mprotect),    // 380
+   LINX_(__NR_pkey_alloc,        sys_pkey_alloc),       // 381
+   LINX_(__NR_pkey_free,         sys_pkey_free),        // 382
    LINXY(__NR_statx,             sys_statx),            // 383
 
    /* Explicitly not supported on i386 yet. */
diff --git a/exp-sgcheck/tests/is_arch_supported b/exp-sgcheck/tests/is_arch_supported
index 818cc61..d4c6191 100755
--- a/exp-sgcheck/tests/is_arch_supported
+++ b/exp-sgcheck/tests/is_arch_supported
@@ -10,6 +10,6 @@
 # architectures.
 
 case \`uname -m\` in
-  ppc*|arm*|s390x|mips*) exit 1;;
+  ppc*|aarch64|arm*|s390x|mips*) exit 1;;
   *)         exit 0;;
 esac
diff --git a/gdbserver_tests/filter_gdb b/gdbserver_tests/filter_gdb
index 6eff229..fd2e8e7 100755
--- a/gdbserver_tests/filter_gdb
+++ b/gdbserver_tests/filter_gdb
@@ -119,6 +119,7 @@ sed -e '/Remote debugging using/,/vgdb launched process attached/d'
     -e 's/in select ()\$/in syscall .../'                                                              \\
     -e 's/in \\.__select ()\$/in syscall .../'                                                          \\
     -e 's/in select () at \\.\\.\\/sysdeps\\/unix\\/syscall-template\\.S.*\$/in syscall .../'                \\
+    -e 's/in \\.__select () at \\.\\.\\/sysdeps\\/unix\\/syscall-template\\.S.*\$/in syscall .../'            \\
     -e '/^[ 	]*at \\.\\.\\/sysdeps\\/unix\\/syscall-template\\.S/d'                                      \\
     -e '/^[ 	]*in \\.\\.\\/sysdeps\\/unix\\/syscall-template\\.S/d'                                      \\
     -e '/^[1-9][0-9]*[ 	]*\\.\\.\\/sysdeps\\/unix\\/syscall-template\\.S/d'                                 \\
diff --git a/glibc-2.34567-NPTL-helgrind.supp b/glibc-2.34567-NPTL-helgrind.supp
index 7ebd2c4..75ad9db 100644
--- a/glibc-2.34567-NPTL-helgrind.supp
+++ b/glibc-2.34567-NPTL-helgrind.supp
@@ -100,6 +100,12 @@
    obj:*/lib*/libpthread-2.*so*
 }
 {
+   helgrind-glibc2X-102a
+   Helgrind:Race
+   fun:mythread_wrapper
+   obj:*vgpreload_helgrind*.so
+}
+{
    helgrind-glibc2X-103
    Helgrind:Race
    fun:pthread_cond_*@@GLIBC_2.*
diff --git a/glibc-2.X.supp.in b/glibc-2.X.supp.in
index 126e8b3..c9af36f 100644
--- a/glibc-2.X.supp.in
+++ b/glibc-2.X.supp.in
@@ -124,7 +124,7 @@
    glibc-2.5.x-on-SUSE-10.2-(PPC)-2a
    Memcheck:Cond
    fun:index
-   obj:*ld-@GLIBC_VERSION@.*.so
+   obj:*ld-@GLIBC_VERSION@*.so
 }
 {
    glibc-2.5.x-on-SuSE-10.2-(PPC)-2b
@@ -136,14 +136,14 @@
    glibc-2.5.5-on-SuSE-10.2-(PPC)-2c
    Memcheck:Addr4
    fun:index
-   obj:*ld-@GLIBC_VERSION@.*.so
+   obj:*ld-@GLIBC_VERSION@*.so
 }
 {
    glibc-2.3.5-on-SuSE-10.1-(PPC)-3
    Memcheck:Addr4
    fun:*wordcopy_fwd_dest_aligned*
    fun:mem*cpy
-   obj:*lib*@GLIBC_VERSION@.*.so
+   obj:*lib*@GLIBC_VERSION@*.so
 }
 
 {
diff --git a/include/pub_tool_redir.h b/include/pub_tool_redir.h
index c97941f..15ba67f 100644
--- a/include/pub_tool_redir.h
+++ b/include/pub_tool_redir.h
@@ -313,7 +313,9 @@
 #define  VG_Z_LD_SO_1               ldZdsoZd1                  // ld.so.1
 #define  VG_U_LD_SO_1               "ld.so.1"
 
+#define  VG_Z_LD_LINUX_AARCH64_SO_1  ldZhlinuxZhaarch64ZdsoZd1
 #define  VG_U_LD_LINUX_AARCH64_SO_1 "ld-linux-aarch64.so.1"
+
 #define  VG_U_LD_LINUX_ARMHF_SO_3   "ld-linux-armhf.so.3"
 
 #endif
diff --git a/include/valgrind.h b/include/valgrind.h
index cc8c2b8..49ecca7 100644
--- a/include/valgrind.h
+++ b/include/valgrind.h
@@ -4687,8 +4687,16 @@ typedef
    r14 in s390_irgen_noredir (VEX/priv/guest_s390_irgen.c) to give the
    function a proper return address. All others are ABI defined call
    clobbers. */
-#define __CALLER_SAVED_REGS "0","1","2","3","4","5","14", \\
-                           "f0","f1","f2","f3","f4","f5","f6","f7"
+#if defined(__VX__) || defined(__S390_VX__)
+#define __CALLER_SAVED_REGS "0", "1", "2", "3", "4", "5", "14",   \\
+      "v0", "v1", "v2", "v3", "v4", "v5", "v6", "v7",             \\
+      "v8", "v9", "v10", "v11", "v12", "v13", "v14", "v15",       \\
+      "v16", "v17", "v18", "v19", "v20", "v21", "v22", "v23",     \\
+      "v24", "v25", "v26", "v27", "v28", "v29", "v30", "v31"
+#else
+#define __CALLER_SAVED_REGS "0", "1", "2", "3", "4", "5", "14",   \\
+      "f0", "f1", "f2", "f3", "f4", "f5", "f6", "f7"
+#endif
 
 /* Nb: Although r11 is modified in the asm snippets below (inside 
    VALGRIND_CFI_PROLOGUE) it is not listed in the clobber section, for
@@ -4710,9 +4718,9 @@ typedef
          "aghi 15,-160\\n\\t"                                      \\
          "lg 1, 0(1)\\n\\t"  /* target->r1 */                      \\
          VALGRIND_CALL_NOREDIR_R1                                \\
-         "lgr %0, 2\\n\\t"                                         \\
          "aghi 15,160\\n\\t"                                       \\
          VALGRIND_CFI_EPILOGUE                                   \\
+         "lgr %0, 2\\n\\t"                                         \\
          : /*out*/   "=d" (_res)                                 \\
          : /*in*/    "d" (&_argvec[0]) __FRAME_POINTER           \\
          : /*trash*/ "cc", "memory", __CALLER_SAVED_REGS,"7"     \\
@@ -4734,9 +4742,9 @@ typedef
          "lg 2, 8(1)\\n\\t"                                        \\
          "lg 1, 0(1)\\n\\t"                                        \\
          VALGRIND_CALL_NOREDIR_R1                                \\
-         "lgr %0, 2\\n\\t"                                         \\
          "aghi 15,160\\n\\t"                                       \\
          VALGRIND_CFI_EPILOGUE                                   \\
+         "lgr %0, 2\\n\\t"                                         \\
          : /*out*/   "=d" (_res)                                 \\
          : /*in*/    "a" (&_argvec[0]) __FRAME_POINTER           \\
          : /*trash*/ "cc", "memory", __CALLER_SAVED_REGS,"7"     \\
@@ -4759,9 +4767,9 @@ typedef
          "lg 3,16(1)\\n\\t"                                        \\
          "lg 1, 0(1)\\n\\t"                                        \\
          VALGRIND_CALL_NOREDIR_R1                                \\
-         "lgr %0, 2\\n\\t"                                         \\
          "aghi 15,160\\n\\t"                                       \\
          VALGRIND_CFI_EPILOGUE                                   \\
+         "lgr %0, 2\\n\\t"                                         \\
          : /*out*/   "=d" (_res)                                 \\
          : /*in*/    "a" (&_argvec[0]) __FRAME_POINTER           \\
          : /*trash*/ "cc", "memory", __CALLER_SAVED_REGS,"7"     \\
@@ -4786,9 +4794,9 @@ typedef
          "lg 4,24(1)\\n\\t"                                        \\
          "lg 1, 0(1)\\n\\t"                                        \\
          VALGRIND_CALL_NOREDIR_R1                                \\
-         "lgr %0, 2\\n\\t"                                         \\
          "aghi 15,160\\n\\t"                                       \\
          VALGRIND_CFI_EPILOGUE                                   \\
+         "lgr %0, 2\\n\\t"                                         \\
          : /*out*/   "=d" (_res)                                 \\
          : /*in*/    "a" (&_argvec[0]) __FRAME_POINTER           \\
          : /*trash*/ "cc", "memory", __CALLER_SAVED_REGS,"7"     \\
@@ -4815,9 +4823,9 @@ typedef
          "lg 5,32(1)\\n\\t"                                        \\
          "lg 1, 0(1)\\n\\t"                                        \\
          VALGRIND_CALL_NOREDIR_R1                                \\
-         "lgr %0, 2\\n\\t"                                         \\
          "aghi 15,160\\n\\t"                                       \\
          VALGRIND_CFI_EPILOGUE                                   \\
+         "lgr %0, 2\\n\\t"                                         \\
          : /*out*/   "=d" (_res)                                 \\
          : /*in*/    "a" (&_argvec[0]) __FRAME_POINTER           \\
          : /*trash*/ "cc", "memory", __CALLER_SAVED_REGS,"7"     \\
@@ -4846,9 +4854,9 @@ typedef
          "lg 6,40(1)\\n\\t"                                        \\
          "lg 1, 0(1)\\n\\t"                                        \\
          VALGRIND_CALL_NOREDIR_R1                                \\
-         "lgr %0, 2\\n\\t"                                         \\
          "aghi 15,160\\n\\t"                                       \\
          VALGRIND_CFI_EPILOGUE                                   \\
+         "lgr %0, 2\\n\\t"                                         \\
          : /*out*/   "=d" (_res)                                 \\
          : /*in*/    "a" (&_argvec[0]) __FRAME_POINTER           \\
          : /*trash*/ "cc", "memory", __CALLER_SAVED_REGS,"6","7" \\
@@ -4880,9 +4888,9 @@ typedef
          "mvc 160(8,15), 48(1)\\n\\t"                              \\
          "lg 1, 0(1)\\n\\t"                                        \\
          VALGRIND_CALL_NOREDIR_R1                                \\
-         "lgr %0, 2\\n\\t"                                         \\
          "aghi 15,168\\n\\t"                                       \\
          VALGRIND_CFI_EPILOGUE                                   \\
+         "lgr %0, 2\\n\\t"                                         \\
          : /*out*/   "=d" (_res)                                 \\
          : /*in*/    "a" (&_argvec[0]) __FRAME_POINTER           \\
          : /*trash*/ "cc", "memory", __CALLER_SAVED_REGS,"6","7" \\
@@ -4916,9 +4924,9 @@ typedef
          "mvc 168(8,15), 56(1)\\n\\t"                              \\
          "lg 1, 0(1)\\n\\t"                                        \\
          VALGRIND_CALL_NOREDIR_R1                                \\
-         "lgr %0, 2\\n\\t"                                         \\
          "aghi 15,176\\n\\t"                                       \\
          VALGRIND_CFI_EPILOGUE                                   \\
+         "lgr %0, 2\\n\\t"                                         \\
          : /*out*/   "=d" (_res)                                 \\
          : /*in*/    "a" (&_argvec[0]) __FRAME_POINTER           \\
          : /*trash*/ "cc", "memory", __CALLER_SAVED_REGS,"6","7" \\
@@ -4954,9 +4962,9 @@ typedef
          "mvc 176(8,15), 64(1)\\n\\t"                              \\
          "lg 1, 0(1)\\n\\t"                                        \\
          VALGRIND_CALL_NOREDIR_R1                                \\
-         "lgr %0, 2\\n\\t"                                         \\
          "aghi 15,184\\n\\t"                                       \\
          VALGRIND_CFI_EPILOGUE                                   \\
+         "lgr %0, 2\\n\\t"                                         \\
          : /*out*/   "=d" (_res)                                 \\
          : /*in*/    "a" (&_argvec[0]) __FRAME_POINTER           \\
          : /*trash*/ "cc", "memory", __CALLER_SAVED_REGS,"6","7" \\
@@ -4994,9 +5002,9 @@ typedef
          "mvc 184(8,15), 72(1)\\n\\t"                              \\
          "lg 1, 0(1)\\n\\t"                                        \\
          VALGRIND_CALL_NOREDIR_R1                                \\
-         "lgr %0, 2\\n\\t"                                         \\
          "aghi 15,192\\n\\t"                                       \\
          VALGRIND_CFI_EPILOGUE                                   \\
+         "lgr %0, 2\\n\\t"                                         \\
          : /*out*/   "=d" (_res)                                 \\
          : /*in*/    "a" (&_argvec[0]) __FRAME_POINTER           \\
          : /*trash*/ "cc", "memory", __CALLER_SAVED_REGS,"6","7" \\
@@ -5036,9 +5044,9 @@ typedef
          "mvc 192(8,15), 80(1)\\n\\t"                              \\
          "lg 1, 0(1)\\n\\t"                                        \\
          VALGRIND_CALL_NOREDIR_R1                                \\
-         "lgr %0, 2\\n\\t"                                         \\
          "aghi 15,200\\n\\t"                                       \\
          VALGRIND_CFI_EPILOGUE                                   \\
+         "lgr %0, 2\\n\\t"                                         \\
          : /*out*/   "=d" (_res)                                 \\
          : /*in*/    "a" (&_argvec[0]) __FRAME_POINTER           \\
          : /*trash*/ "cc", "memory", __CALLER_SAVED_REGS,"6","7" \\
@@ -5080,9 +5088,9 @@ typedef
          "mvc 200(8,15), 88(1)\\n\\t"                              \\
          "lg 1, 0(1)\\n\\t"                                        \\
          VALGRIND_CALL_NOREDIR_R1                                \\
-         "lgr %0, 2\\n\\t"                                         \\
          "aghi 15,208\\n\\t"                                       \\
          VALGRIND_CFI_EPILOGUE                                   \\
+         "lgr %0, 2\\n\\t"                                         \\
          : /*out*/   "=d" (_res)                                 \\
          : /*in*/    "a" (&_argvec[0]) __FRAME_POINTER           \\
          : /*trash*/ "cc", "memory", __CALLER_SAVED_REGS,"6","7" \\
@@ -5126,9 +5134,9 @@ typedef
          "mvc 208(8,15), 96(1)\\n\\t"                              \\
          "lg 1, 0(1)\\n\\t"                                        \\
          VALGRIND_CALL_NOREDIR_R1                                \\
-         "lgr %0, 2\\n\\t"                                         \\
          "aghi 15,216\\n\\t"                                       \\
          VALGRIND_CFI_EPILOGUE                                   \\
+         "lgr %0, 2\\n\\t"                                         \\
          : /*out*/   "=d" (_res)                                 \\
          : /*in*/    "a" (&_argvec[0]) __FRAME_POINTER           \\
          : /*trash*/ "cc", "memory", __CALLER_SAVED_REGS,"6","7" \\
diff --git a/memcheck/tests/arm64-linux/scalar.c b/memcheck/tests/arm64-linux/scalar.c
index fd49db6..622ea1c 100644
--- a/memcheck/tests/arm64-linux/scalar.c
+++ b/memcheck/tests/arm64-linux/scalar.c
@@ -136,7 +136,7 @@ int main(void)
 
    // __NR_setuid 23
    GO(__NR_setuid, "1s 0m");
-   SY(__NR_setuid, x0); FAIL;
+   SY(__NR_setuid, x0-1); FAIL;
 
    // __NR_getuid 24
    GO(__NR_getuid, "0s 0m");
@@ -229,7 +229,7 @@ int main(void)
 
    // __NR_setgid 46
    GO(__NR_setgid, "1s 0m");
-   SY(__NR_setgid, x0); FAIL;
+   SY(__NR_setgid, x0-1); FAIL;
 
    // __NR_getgid 47
    GO(__NR_getgid, "0s 0m");
@@ -249,7 +249,7 @@ int main(void)
 
    // __NR_acct 51
    GO(__NR_acct, "1s 1m");
-   SY(__NR_acct, x0); FAIL;
+   SY(__NR_acct, x0-1); FAIL;
 
    // __NR_umount2 52
    GO(__NR_umount2, "2s 1m");
@@ -340,11 +340,11 @@ int main(void)
 
    // __NR_setreuid 70
    GO(__NR_setreuid, "2s 0m");
-   SY(__NR_setreuid, x0, x0); FAIL;
+   SY(__NR_setreuid, x0-1, x0-1); SUCC;
 
    // __NR_setregid 71
    GO(__NR_setregid, "2s 0m");
-   SY(__NR_setregid, x0, x0); FAIL;
+   SY(__NR_setregid, x0-1, x0-1); SUCC;
 
    // __NR_sigsuspend arm64 only has rt_sigsuspend
    // XXX: how do you use this function?
@@ -447,7 +447,7 @@ int main(void)
 
    // __NR_fchown 95
    GO(__NR_fchown, "3s 0m");
-   SY(__NR_fchown, x0, x0, x0); FAIL;
+   SY(__NR_fchown, x0-1, x0, x0); FAIL;
 
    // __NR_getpriority 96
    GO(__NR_getpriority, "2s 0m");
@@ -733,7 +733,7 @@ int main(void)
 
    // __NR_setresuid 164
    GO(__NR_setresuid, "3s 0m");
-   SY(__NR_setresuid, x0, x0, x0); FAIL;
+   SY(__NR_setresuid, x0-1, x0-1, x0-1); SUCC;
 
    // __NR_getresuid 165
    GO(__NR_getresuid, "3s 3m");
@@ -757,7 +757,7 @@ int main(void)
 
    // __NR_setresgid 170
    GO(__NR_setresgid, "3s 0m");
-   SY(__NR_setresgid, x0, x0, x0); FAIL;
+   SY(__NR_setresgid, x0-1, x0-1, x0-1); SUCC;
 
    // __NR_getresgid 171
    GO(__NR_getresgid, "3s 3m");
diff --git a/memcheck/tests/linux/Makefile.am b/memcheck/tests/linux/Makefile.am
index d7515d9..00e99a5 100644
--- a/memcheck/tests/linux/Makefile.am
+++ b/memcheck/tests/linux/Makefile.am
@@ -20,6 +20,7 @@ EXTRA_DIST = \\
 	stack_switch.stderr.exp stack_switch.vgtest \\
 	syscalls-2007.vgtest syscalls-2007.stderr.exp \\
 	syslog-syscall.vgtest syslog-syscall.stderr.exp \\
+	sys-copy_file_range.vgtest sys-copy_file_range.stderr.exp \\
 	sys-openat.vgtest sys-openat.stderr.exp sys-openat.stdout.exp \\
 	sys-statx.vgtest sys-statx.stderr.exp \\
 	timerfd-syscall.vgtest timerfd-syscall.stderr.exp \\
@@ -49,6 +50,10 @@ if HAVE_AT_FDCWD
 check_PROGRAMS += sys-openat
 endif
 
+if HAVE_COPY_FILE_RANGE
+        check_PROGRAMS += sys-copy_file_range
+endif
+
 AM_CFLAGS   += \$(AM_FLAG_M3264_PRI)
 AM_CXXFLAGS += \$(AM_FLAG_M3264_PRI)
 
diff --git a/memcheck/tests/linux/sys-copy_file_range.c b/memcheck/tests/linux/sys-copy_file_range.c
new file mode 100644
index 0000000..3022fa1
--- /dev/null
+++ b/memcheck/tests/linux/sys-copy_file_range.c
@@ -0,0 +1,67 @@
+#define _GNU_SOURCE
+#include <fcntl.h>
+#include <stdio.h>
+#include <stdlib.h>
+#include <sys/stat.h>
+#include <unistd.h>
+#include "../../memcheck.h"
+
+int main(int argc, char **argv)
+{
+    int fd_in, fd_out;
+    struct stat stat;
+    loff_t len, ret;
+
+    fd_in = open("copy_file_range_source", O_CREAT | O_RDWR, 0644);
+    if (fd_in == -1) {
+        perror("open copy_file_range_source");
+        exit(EXIT_FAILURE);
+    }
+
+    if (write(fd_in, "foo bar\\n", 8) != 8) {
+        perror("writing to the copy_file_range_source");
+        exit(EXIT_FAILURE);
+    }
+    lseek(fd_in, 0, SEEK_SET);
+
+    if (fstat(fd_in, &stat) == -1) {
+        perror("fstat");
+        exit(EXIT_FAILURE);
+    }
+
+    len = stat.st_size;
+
+    fd_out = open("copy_file_range_dest", O_CREAT | O_WRONLY | O_TRUNC, 0644);
+    if (fd_out == -1) {
+        perror("open copy_file_range_dest");
+        exit(EXIT_FAILURE);
+    }
+
+    /* Check copy_file_range called with the correct arguments works. */
+    do {
+        ret = copy_file_range(fd_in, NULL, fd_out, NULL, len, 0);
+        if (ret == -1) {
+            perror("copy_file_range");
+            exit(EXIT_FAILURE);
+        }
+
+        len -= ret;
+    } while (len > 0);
+
+    /* Check valgrind will produce expected warnings for the
+       various wrong arguments. */
+    do {
+        void *t = 0; VALGRIND_MAKE_MEM_UNDEFINED (&t, sizeof (void *));
+        void *z = (void *) -1;
+
+        ret = copy_file_range(fd_in, t, fd_out, NULL, len, 0);
+        ret = copy_file_range(fd_in, NULL, fd_out, z, len, 0);
+        ret = copy_file_range(- 1, NULL, - 1, NULL, len, 0);
+    } while (0);
+
+    close(fd_in);
+    close(fd_out);
+    unlink("copy_file_range_source");
+    unlink("copy_file_range_dest");
+    exit(EXIT_SUCCESS);
+}
diff --git a/memcheck/tests/linux/sys-copy_file_range.stderr.exp b/memcheck/tests/linux/sys-copy_file_range.stderr.exp
new file mode 100644
index 0000000..1aa4dc2
--- /dev/null
+++ b/memcheck/tests/linux/sys-copy_file_range.stderr.exp
@@ -0,0 +1,21 @@
+
+Syscall param copy_file_range("off_in") contains uninitialised byte(s)
+   ...
+   by 0x........: main (sys-copy_file_range.c:57)
+
+Syscall param copy_file_range(off_out) points to unaddressable byte(s)
+   ...
+   by 0x........: main (sys-copy_file_range.c:58)
+ Address 0x........ is not stack'd, malloc'd or (recently) free'd
+
+Warning: invalid file descriptor -1 in syscall copy_file_range(fd_in)()
+
+HEAP SUMMARY:
+    in use at exit: 0 bytes in 0 blocks
+  total heap usage: 0 allocs, 0 frees, 0 bytes allocated
+
+For a detailed leak analysis, rerun with: --leak-check=full
+
+Use --track-origins=yes to see where uninitialised values come from
+For lists of detected and suppressed errors, rerun with: -s
+ERROR SUMMARY: 2 errors from 2 contexts (suppressed: 0 from 0)
diff --git a/memcheck/tests/linux/sys-copy_file_range.vgtest b/memcheck/tests/linux/sys-copy_file_range.vgtest
new file mode 100644
index 0000000..b7741e8
--- /dev/null
+++ b/memcheck/tests/linux/sys-copy_file_range.vgtest
@@ -0,0 +1,2 @@
+prereq: test -e sys-copy_file_range
+prog: sys-copy_file_range
diff --git a/memcheck/tests/x86-linux/scalar.c b/memcheck/tests/x86-linux/scalar.c
index 213a5ad..52f0d4e 100644
--- a/memcheck/tests/x86-linux/scalar.c
+++ b/memcheck/tests/x86-linux/scalar.c
@@ -145,7 +145,7 @@ int main(void)
 
    // __NR_setuid 23
    GO(__NR_setuid, "1s 0m");
-   SY(__NR_setuid, x0); FAIL;
+   SY(__NR_setuid, x0-1); FAIL;
 
    // __NR_getuid 24
    GO(__NR_getuid, "0s 0m");
@@ -238,7 +238,7 @@ int main(void)
 
    // __NR_setgid 46
    GO(__NR_setgid, "1s 0m");
-   SY(__NR_setgid, x0); FAIL;
+   SY(__NR_setgid, x0-1); FAIL;
 
    // __NR_getgid 47
    GO(__NR_getgid, "0s 0m");
@@ -258,7 +258,7 @@ int main(void)
 
    // __NR_acct 51
    GO(__NR_acct, "1s 1m");
-   SY(__NR_acct, x0); FAIL;
+   SY(__NR_acct, x0-1); FAIL;
 
    // __NR_umount2 52
    GO(__NR_umount2, "2s 1m");
@@ -349,11 +349,11 @@ int main(void)
 
    // __NR_setreuid 70
    GO(__NR_setreuid, "2s 0m");
-   SY(__NR_setreuid, x0, x0); FAIL;
+   SY(__NR_setreuid, x0-1, x0-1); SUCC;
 
    // __NR_setregid 71
    GO(__NR_setregid, "2s 0m");
-   SY(__NR_setregid, x0, x0); FAIL;
+   SY(__NR_setregid, x0-1, x0-1); SUCC;
 
    // __NR_sigsuspend 72
    // XXX: how do you use this function?
@@ -456,7 +456,7 @@ int main(void)
 
    // __NR_fchown 95
    GO(__NR_fchown, "3s 0m");
-   SY(__NR_fchown, x0, x0, x0); FAIL;
+   SY(__NR_fchown, x0-1, x0, x0); FAIL;
 
    // __NR_getpriority 96
    GO(__NR_getpriority, "2s 0m");
@@ -742,7 +742,7 @@ int main(void)
 
    // __NR_setresuid 164
    GO(__NR_setresuid, "3s 0m");
-   SY(__NR_setresuid, x0, x0, x0); FAIL;
+   SY(__NR_setresuid, x0-1, x0-1, x0-1); SUCC;
 
    // __NR_getresuid 165
    GO(__NR_getresuid, "3s 3m");
@@ -766,7 +766,7 @@ int main(void)
 
    // __NR_setresgid 170
    GO(__NR_setresgid, "3s 0m");
-   SY(__NR_setresgid, x0, x0, x0); FAIL;
+   SY(__NR_setresgid, x0-1, x0-1, x0-1); SUCC;
 
    // __NR_getresgid 171
    GO(__NR_getresgid, "3s 3m");
@@ -923,11 +923,11 @@ int main(void)
 
    // __NR_setreuid32 203
    GO(__NR_setreuid32, "2s 0m");
-   SY(__NR_setreuid32, x0, x0); FAIL;
+   SY(__NR_setreuid32, x0-1, x0-1); SUCC;
 
    // __NR_setregid32 204
    GO(__NR_setregid32, "2s 0m");
-   SY(__NR_setregid32, x0, x0); FAIL;
+   SY(__NR_setregid32, x0-1, x0-1); SUCC;
 
    // __NR_getgroups32 205
    GO(__NR_getgroups32, "2s 1m");
@@ -939,11 +939,11 @@ int main(void)
 
    // __NR_fchown32 207
    GO(__NR_fchown32, "3s 0m");
-   SY(__NR_fchown32, x0, x0, x0); FAIL;
+   SY(__NR_fchown32, x0-1, x0, x0); FAIL;
 
    // __NR_setresuid32 208
    GO(__NR_setresuid32, "3s 0m");
-   SY(__NR_setresuid32, x0, x0, x0); FAIL;
+   SY(__NR_setresuid32, x0-1, x0-1, x0-1); SUCC;
 
    // __NR_getresuid32 209
    GO(__NR_getresuid32, "3s 3m");
@@ -951,7 +951,7 @@ int main(void)
 
    // __NR_setresgid32 210
    GO(__NR_setresgid32, "3s 0m");
-   SY(__NR_setresgid32, x0, x0, x0); FAIL;
+   SY(__NR_setresgid32, x0-1, x0-1, x0-1); SUCC;
 
    // __NR_getresgid32 211
    GO(__NR_getresgid32, "3s 3m");
@@ -963,11 +963,11 @@ int main(void)
 
    // __NR_setuid32 213
    GO(__NR_setuid32, "1s 0m");
-   SY(__NR_setuid32, x0); FAIL;
+   SY(__NR_setuid32, x0-1); FAIL;
 
    // __NR_setgid32 214
    GO(__NR_setgid32, "1s 0m");
-   SY(__NR_setgid32, x0); FAIL;
+   SY(__NR_setgid32, x0-1); FAIL;
 
    // __NR_setfsuid32 215
    GO(__NR_setfsuid32, "1s 0m");
diff --git a/mpi/Makefile.am b/mpi/Makefile.am
index 7ad9a25..471fee0 100644
--- a/mpi/Makefile.am
+++ b/mpi/Makefile.am
@@ -18,16 +18,18 @@ EXTRA_DIST = \\
 # libmpiwrap-<platform>.so
 #----------------------------------------------------------------------------
 
-noinst_PROGRAMS  =
+# These are really real libraries, so they should go to libdir, not libexec.
+mpidir = \$(pkglibdir)
+mpi_PROGRAMS  =
 if BUILD_MPIWRAP_PRI
-noinst_PROGRAMS += libmpiwrap-@VGCONF_ARCH_PRI@-@VGCONF_OS@.so
+mpi_PROGRAMS += libmpiwrap-@VGCONF_ARCH_PRI@-@VGCONF_OS@.so
 endif
 if BUILD_MPIWRAP_SEC
-noinst_PROGRAMS += libmpiwrap-@VGCONF_ARCH_SEC@-@VGCONF_OS@.so
+mpi_PROGRAMS += libmpiwrap-@VGCONF_ARCH_SEC@-@VGCONF_OS@.so
 endif
 
 if VGCONF_OS_IS_DARWIN
-noinst_DSYMS = \$(noinst_PROGRAMS)
+mpi_DSYMS = \$(mpi_PROGRAMS)
 endif
 
 
diff --git a/none/tests/s390x/Makefile.am b/none/tests/s390x/Makefile.am
index 097c85a..900f1ab 100644
--- a/none/tests/s390x/Makefile.am
+++ b/none/tests/s390x/Makefile.am
@@ -18,8 +18,7 @@ INSN_TESTS = clc clcle cvb cvd icm lpr tcxb lam_stam xc mvst add sub mul \\
 	     spechelper-cr  spechelper-clr  \\
 	     spechelper-ltr spechelper-or   \\
 	     spechelper-icm-1  spechelper-icm-2 spechelper-tmll \\
-	     spechelper-tm laa vector lsc2 ppno vector_string vector_integer \\
-	     vector_float
+	     spechelper-tm laa 
 
 if BUILD_DFP_TESTS
   INSN_TESTS += dfp-1 dfp-2 dfp-3 dfp-4 dfptest dfpext dfpconv srnmt pfpo
@@ -68,8 +67,3 @@ cu24_1_CFLAGS    = \$(AM_CFLAGS) -DM3=1
 fixbr_CFLAGS     = \$(AM_CFLAGS) @FLAG_MLONG_DOUBLE_128@
 fpext_CFLAGS     = \$(AM_CFLAGS) @FLAG_MLONG_DOUBLE_128@
 ex_clone_LDADD   = -lpthread
-vector_CFLAGS    = \$(AM_CFLAGS) -march=z13
-lsc2_CFLAGS       = -march=z13 -DS390_TESTS_NOCOLOR
-vector_string_CFLAGS = \$(AM_CFLAGS) -march=z13 -DS390_TEST_COUNT=5
-vector_integer_CFLAGS    = \$(AM_CFLAGS) -march=z13 -DS390_TEST_COUNT=4
-vector_float_CFLAGS    = \$(AM_CFLAGS) -march=z13 -DS390_TEST_COUNT=4
diff --git a/shared/vg_replace_strmem.c b/shared/vg_replace_strmem.c
index 89a7dcc..19143cf 100644
--- a/shared/vg_replace_strmem.c
+++ b/shared/vg_replace_strmem.c
@@ -1160,6 +1160,7 @@ static inline void my_exit ( int x )
  STPCPY(VG_Z_LIBC_SONAME,          __stpcpy_sse2_unaligned)
  STPCPY(VG_Z_LD_LINUX_SO_2,        stpcpy)
  STPCPY(VG_Z_LD_LINUX_X86_64_SO_2, stpcpy)
+ STPCPY(VG_Z_LD_LINUX_AARCH64_SO_1,stpcpy)
 
 #elif defined(VGO_darwin)
  //STPCPY(VG_Z_LIBC_SONAME,          stpcpy)
EOF
./autogen.sh && env CFLAGS='-O3 -g -Wall -pipe' CXXFLAGS='-O3 -g -pipe' CC='gcc -O3 -g -pipe' ./configure --build=x86_64-redhat-linux-gnu --host=x86_64-redhat-linux-gnu --target=x86_64-redhat-linux-gnu --program-prefix= --prefix=/usr --exec-prefix=/usr --bindir=/usr/bin --sbindir=/usr/sbin --sysconfdir=/etc --datadir=/usr/share --includedir=/usr/include --libdir=/usr/lib64 --libexecdir=/usr/libexec --localstatedir=/var --sharedstatedir=/var/lib --mandir=/usr/share/man --infodir=/usr/share/info --with-mpicc=/usr/lib64/openmpi/bin/mpicc --enable-only64bit GDB=/usr/bin/gdb 'CFLAGS=-O3 -g -Wall -pipe' 'CXXFLAGS=-O3 -g -pipe' 'CC=gcc -O3 -g -pipe' && make -j8 && make install
cd $HOME ; rm -rf valgrind-3.15.0 valgrind-3.15.0.tar.bz2

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
    service mysqld start
    service postfix start
    service memcached start
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
git clone https://github.com/lavabit/magma.git magma-develop; error
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
dev/scripts/database/schema.reset.sh; error

# Controls whether ClamAV is enabled, and/or if the signature databases get updated.
MAGMA_CLAMAV=\$(echo \$MAGMA_CLAMAV | tr "[:lower:]" "[:upper:]")
MAGMA_CLAMAV_FRESHEN=\$(echo \$MAGMA_CLAMAV_FRESHEN | tr "[:lower:]" "[:upper:]")
MAGMA_CLAMAV_DOWNLOAD=\$(echo \$MAGMA_CLAMAV_DOWNLOAD | tr "[:lower:]" "[:upper:]")
( cp /var/lib/clamav/bytecode.cvd sandbox/virus/ && cp /var/lib/clamav/daily.cvd sandbox/virus/ && cp /var/lib/clamav/main.cvd sandbox/virus/ ) || echo "Unable to use the system copy of the virus databases."
if [ "\$MAGMA_CLAMAV" == "YES" ]; then
  sed -i -e "s/virus.available = false/virus.available = true/g" sandbox/etc/magma.sandbox.config
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
  dev/scripts/freshen/freshen.clamav.sh 2>&1 | grep -v WARNING | grep -v PANIC; error
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
make all; error

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
MAGMA_MEMCHECK=\$(echo \$MAGMA_MEMCHECK | tr "[:lower:]" "[:upper:]")
if [ "\$MAGMA_MEMCHECK" == "YES" ]; then
  dev/scripts/launch/check.vg
fi

# Daemonize instead of running on the console.
sed -i -e "s/magma.output.file = false/magma.output.file = true/g" sandbox/etc/magma.sandbox.config

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
