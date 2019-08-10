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

# Ensure dmidecode is available.
retry apk add dmidecode

# Bail if we are not running atop VirtualBox.
if [[ `dmidecode -s system-product-name` != "VirtualBox" ]]; then
    exit 0
fi

# Install the Virtual Box Tools from source
printf "Installing the Virtual Box Tools.\n"

# Install build dependencies
echo "@comm36 https://dl-4.alpinelinux.org/alpine/v3.6/community" >> /etc/apk/repositories
apk update
apk add gcc g++ yasm nasm kbuild@comm36 linux-virtgrsec-dev linux-headers zlib-dev make

# Fetch the VirtualBox source and prepare it for building
wget http://download.virtualbox.org/virtualbox/5.1.14/VirtualBox-5.1.14.tar.bz2
tar -xf VirtualBox-5.1.14.tar.bz2
rm -rf VirtualBox-5.1.14.tar.bz2
cd VirtualBox-5.1.14
rm -rf kBuild/bin tools

patch -p1 << 'EOF'
--- a/src/VBox/Additions/common/VBoxGuestLib/Makefile.kmk
+++ b/src/VBox/Additions/common/VBoxGuestLib/Makefile.kmk
@@ -38,16 +38,6 @@
 LIBRARIES += \
 	VBoxGuestR3Lib \
 	VBoxGuestR3LibShared
-ifndef VBOX_ONLY_VALIDATIONKIT
- if1of ($(KBUILD_TARGET), freebsd linux netbsd openbsd)
-  LIBRARIES += \
-  	VBoxGuestR3LibXFree86
- endif
- if1of ($(KBUILD_TARGET), freebsd linux netbsd openbsd solaris)
-  LIBRARIES += \
-  	VBoxGuestR3LibXOrg
- endif
-endif
 LIBRARIES.win.amd64 += VBoxGuestR3Lib-x86 VBoxGuestR3LibShared-x86
 
 
--- a/src/VBox/Runtime/include/internal/fs.h
+++ b/src/VBox/Runtime/include/internal/fs.h
@@ -49,8 +49,6 @@
 #ifdef RT_OS_LINUX
 # ifdef __USE_MISC
 #  define HAVE_STAT_TIMESPEC_BRIEF
-# else
-#  define HAVE_STAT_NSEC
 # endif
 #endif
 
--- a/src/VBox/Runtime/r3/linux/semevent-linux.cpp
+++ b/src/VBox/Runtime/r3/linux/semevent-linux.cpp
@@ -25,7 +25,7 @@
  */
 
 #include <features.h>
-#if __GLIBC_PREREQ(2,6) && !defined(IPRT_WITH_FUTEX_BASED_SEMS)
+#if defined(__GLIBC__) && !defined(IPRT_WITH_FUTEX_BASED_SEMS)
 
 /*
  * glibc 2.6 fixed a serious bug in the mutex implementation. We wrote this
--- a/src/VBox/Runtime/r3/linux/semeventmulti-linux.cpp
+++ b/src/VBox/Runtime/r3/linux/semeventmulti-linux.cpp
@@ -26,7 +26,7 @@
 
 
 #include <features.h>
-#if __GLIBC_PREREQ(2,6) && !defined(IPRT_WITH_FUTEX_BASED_SEMS)
+#if defined(__GLIBC__) && !defined(IPRT_WITH_FUTEX_BASED_SEMS)
 
 /*
  * glibc 2.6 fixed a serious bug in the mutex implementation. We wrote this
--- a/src/VBox/Runtime/r3/linux/sysfs.cpp
+++ b/src/VBox/Runtime/r3/linux/sysfs.cpp
@@ -43,7 +43,6 @@
 
 #include <unistd.h>
 #include <stdio.h>
-#include <sys/sysctl.h>
 #include <sys/stat.h>
 #include <sys/fcntl.h>
 #include <errno.h>
--- a/src/VBox/Runtime/r3/linux/thread-affinity-linux.cpp
+++ b/src/VBox/Runtime/r3/linux/thread-affinity-linux.cpp
@@ -32,6 +32,8 @@
 # define _GNU_SOURCE
 #endif
 #include <features.h>
+
+#if defined(__GLIBC__)
 #if __GLIBC_PREREQ(2,4)
 
 #include <sched.h>
@@ -87,6 +89,11 @@
 
     return VINF_SUCCESS;
 }
+
+#else
+# include "../../generic/RTThreadGetAffinity-stub-generic.cpp"
+# include "../../generic/RTThreadSetAffinity-stub-generic.cpp"
+#endif
 
 #else
 # include "../../generic/RTThreadGetAffinity-stub-generic.cpp"
--- a/src/VBox/Runtime/r3/posix/fileio2-posix.cpp
+++ b/src/VBox/Runtime/r3/posix/fileio2-posix.cpp
@@ -188,7 +188,12 @@
 
     /* XXX this falls back to utimes("/proc/self/fd/...",...) for older kernels/glibcs and this
      * will not work for hardened builds where this directory is owned by root.root and mode 0500 */
-    if (futimes(RTFileToNative(hFile), aTimevals))
+    struct timespec aTimespecs[2] = {
+    	{ aTimevals[0].tv_sec, aTimevals[0].tv_usec * 1000 },
+    	{ aTimevals[1].tv_sec, aTimevals[1].tv_usec * 1000 },
+    };
+
+    if (futimens(RTFileToNative(hFile), aTimespecs))
     {
         int rc = RTErrConvertFromErrno(errno);
         Log(("RTFileSetTimes(%RTfile,%p,%p,,): returns %Rrc\n", hFile, pAccessTime, pModificationTime, rc));
--- a/src/VBox/Runtime/r3/posix/semevent-posix.cpp
+++ b/src/VBox/Runtime/r3/posix/semevent-posix.cpp
@@ -44,17 +44,9 @@
 #include <pthread.h>
 #include <unistd.h>
 #include <sys/time.h>
+#include <sched.h>
 
-#ifdef RT_OS_DARWIN
-# define pthread_yield() pthread_yield_np()
-#endif
 
-#if defined(RT_OS_SOLARIS) || defined(RT_OS_HAIKU) || defined(RT_OS_FREEBSD) || defined(RT_OS_NETBSD)
-# include <sched.h>
-# define pthread_yield() sched_yield()
-#endif
-
-
 /*********************************************************************************************************************************
 *   Structures and Typedefs                                                                                                      *
 *********************************************************************************************************************************/
@@ -317,7 +309,7 @@
         /* for fairness, yield before going to sleep. */
         if (    ASMAtomicIncU32(&pThis->cWaiters) > 1
             &&  pThis->u32State == EVENT_STATE_SIGNALED)
-            pthread_yield();
+            sched_yield();
 
          /* take mutex */
         int rc = pthread_mutex_lock(&pThis->Mutex);
@@ -405,7 +397,7 @@
 
         /* for fairness, yield before going to sleep. */
         if (ASMAtomicIncU32(&pThis->cWaiters) > 1 && cMillies)
-            pthread_yield();
+            sched_yield();
 
         /* take mutex */
         int rc = pthread_mutex_lock(&pThis->Mutex);
--- a/src/VBox/Runtime/r3/posix/thread2-posix.cpp
+++ b/src/VBox/Runtime/r3/posix/thread2-posix.cpp
@@ -63,7 +63,7 @@
 #elif defined(RT_OS_SOLARIS) || defined(RT_OS_HAIKU) || defined(RT_OS_FREEBSD) || defined(RT_OS_NETBSD)
         sched_yield();
 #else
-        if (!pthread_yield())
+        if (!sched_yield())
 #endif
         {
             LogFlow(("RTThreadSleep: returning %Rrc (cMillies=%d)\n", VINF_SUCCESS, cMillies));
@@ -100,7 +100,7 @@
 #elif defined(RT_OS_SOLARIS) || defined(RT_OS_HAIKU) || defined(RT_OS_FREEBSD) || defined(RT_OS_NETBSD)
         sched_yield();
 #else
-        if (!pthread_yield())
+        if (!sched_yield())
 #endif
             return VINF_SUCCESS;
     }
@@ -126,10 +126,8 @@
 #endif
 #ifdef RT_OS_DARWIN
     pthread_yield_np();
-#elif defined(RT_OS_SOLARIS) || defined(RT_OS_HAIKU) || defined(RT_OS_FREEBSD) || defined(RT_OS_NETBSD)
-    sched_yield();
 #else
-    pthread_yield();
+    sched_yield();
 #endif
 #if defined(RT_ARCH_AMD64) || defined(RT_ARCH_X86)
     u64TS = ASMReadTSC() - u64TS;
--- a/src/libs/kStuff/kStuff/include/k/kDefs.h
+++ b/src/libs/kStuff/kStuff/include/k/kDefs.h
@@ -82,7 +82,7 @@
 #  define K_OS      K_OS_DRAGONFLY
 # elif defined(__FreeBSD__) /*??*/
 #  define K_OS      K_OS_FREEBSD
-# elif defined(__gnu_linux__)
+# elif defined(__linux__)
 #  define K_OS      K_OS_LINUX
 # elif defined(__NetBSD__) /*??*/
 #  define K_OS      K_OS_NETBSD
--- a/src/VBox/Additions/common/VBoxGuest/linux/Makefile
+++ b/src/VBox/Additions/common/VBoxGuest/linux/Makefile
@@ -108,7 +108,7 @@
 
 MOD_DEFS = -DVBOX -DRT_OS_LINUX -DIN_RING0 -DIN_RT_R0 -DIN_GUEST \
             -DIN_GUEST_R0 -DIN_MODULE -DRT_WITH_VBOX -DVBGL_VBOXGUEST \
-            -DVBOX_WITH_HGCM
+            -DVBOX_WITH_HGCM -DLOG_USE_C99
 ifeq ($(BUILD_TARGET_ARCH),amd64)
  MOD_DEFS  += -DRT_ARCH_AMD64
 else
--- a/src/VBox/Additions/linux/export_modules
+++ b/src/VBox/Additions/linux/export_modules
@@ -16,7 +16,7 @@
 #
 
 # The below is GNU-specific.  See VBox.sh for the longer Solaris/OS X version.
-TARGET=`readlink -e -- "${0}"` || exit 1
+TARGET=`readlink -f -- "${0}"` || exit 1
 MY_DIR="${TARGET%/[!/]*}"
 
 if [ -z "$1" ]; then
EOF

cat << 'EOF' > LocalConfig.kmk
# -*- Makefile -*-
#
# Overwrite some default kBuild settings
#

#
# Copyright (C) 2006-2008 Sun Microsystems, Inc.
#
# This file is part of VirtualBox Open Source Edition (OSE), as
# available from http://www.virtualbox.org. This file is free software;
# you can redistribute it and/or modify it under the terms of the GNU
# General Public License as published by the Free Software Foundation,
# in version 2 as it comes in the "COPYING" file of the VirtualBox OSE
# distribution. VirtualBox OSE is distributed in the hope that it will
# be useful, but WITHOUT ANY WARRANTY of any kind.
#

# don't build testcases to save time, they are not needed for the package
VBOX_WITH_TESTCASES     :=
VBOX_WITH_VALIDATIONKIT :=

KBUILD_MSG_STYLE        := brief

## paths, origin, hardening
VBOX_WITH_HARDENING        := 2
VBOX_WITH_ORIGIN           :=
VBOX_ONLY_ADDITIONS     := 1

## don't build with -Werror
VBOX_WITH_WARNINGS_AS_ERRORS :=

## Disable anything X11 related
VBOX_X11_SEAMLESS_GUEST :=
VBOX_WITH_X11_ADDITIONS :=
WITH_X11 :=
VBOX_WITH_DRAG_AND_DROP :=
VBOX_WITH_PAM :=

TOOL_YASM_AS := yasm
EOF

# Build the guest additions
./configure --nofatal --disable-dbus --disable-xpcom --disable-sdl-ttf --disable-pulse --disable-alsa --build-headless
source env.sh
kmk all

# Install the guest additions
cp out/linux.amd64/release/bin/additions/VBoxService /usr/sbin/VBoxService
cp out/linux.amd64/release/bin/additions/VBoxControl /usr/sbin/VBoxControl
cp out/linux.amd64/release/bin/additions/mount.vboxsf /sbin/mount.vboxsf

cat << 'EOF' > /etc/init.d/vbox-additions
#!/sbin/openrc-run
# Copyright 1999-2013 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Id$

description="VirtualBox control service"

pidfile="/var/run/vboxguest-service.pid"
command="/usr/sbin/VBoxService"
command_args="--foreground"
start_stop_daemon_args="--make-pidfile --pidfile ${pidfile} --background"

depend() {
        need localmount
}

start_pre() {
	einfo "Loading kernel modules"
	/sbin/modprobe vboxguest 2>&1 && \
	/sbin/modprobe vboxsf 2>&1
	eend $?
}

stop_pre() {
	einfo "Unmounting shared folders"
	/bin/grep vboxsf /proc/mounts | /usr/bin/cut -f2 -d' ' | /usr/bin/xargs -n1 -r /bin/umount
	eend $?
}

stop_post() {
	einfo "Removing kernel modules"
	/sbin/modprobe -r vboxsf 2>&1 && \
	/sbin/modprobe -r vboxguest 2>&1
	eend $?
}
EOF

chmod +x /etc/init.d/vbox-additions
rc-update add vbox-additions

# Build the modules and install them
cd out/linux.amd64/release/bin/additions/src
rm -rf vboxvideo
make
make install

# Cleanup
cd /root/
rm -rf VirtualBox-5.1.14
apk del gcc g++ yasm nasm kbuild linux-virtgrsec-dev linux-headers zlib-dev make
sed -i '/@comm36/d' /etc/apk/repositories
apk update
rm -rf /root/VBoxVersion.txt
rm -rf /root/VBoxGuestAdditions.iso

printf "Finished installing the Virtual Box Tools.\n"

# Boosts the available entropy which allows magma to start faster.
retry apk add haveged

# Autostart the haveged daemon.
rc-update add haveged default && rc-service haveged start
