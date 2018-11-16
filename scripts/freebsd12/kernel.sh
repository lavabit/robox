#!/bin/bash -eux

# Disable jemalloc debugging.
ln -sf 'abort:false,junk:false' /etc/malloc.conf

# Disable crash dumps.
sysrc dumpdev="NO"

# Boot faster.
echo 'autoboot_delay="-1"' >> /boot/loader.conf

# Disabling beastie boot screen.
echo 'beastie_disable="YES"' >> /boot/loader.conf
echo 'kern.hz=50' >> /boot/loader.conf

# Skip the panic screen during reboots.
echo 'debug.trace_on_panic=1' >> /etc/sysctl.conf
echo 'debug.debugger_on_panic=0' >> /etc/sysctl.conf
echo 'kern.panic_reboot_wait_time=0' >> /etc/sysctl.conf
