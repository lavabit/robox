#!/bin/bash -eux

# Ensure the network shuts down properly.
printf 'keep_network="NO"\n' >> /etc/rc.conf

# Ensure SSHD waits until the network is up and running before launching.
printf 'rc_need="net-online"\n' >> /etc/conf.d/sshd

# Set up the required interfaces.
printf 'interfaces="eth0"\n' >> /etc/conf.d/net-online
printf 'timeout=120\n' >> /etc/conf.d/net-online

patch -p1 /etc/init.d/net-online <<-EOF
diff --git a/net-online b/net-online
index c7031bb..815c4fe 100755
--- a/net-online
+++ b/net-online
@@ -15,6 +15,7 @@ depend()
 {
 	after modules
 	need sysfs
+	provide network-online
 	keyword -docker -jail -lxc -openvz -prefix -systemd-nspawn -uml -vserver
 }
 
@@ -27,23 +28,10 @@ get_interfaces()
 	done
 }
 
-get_default_gateway()
-{
-	local cmd gateway
-	if command -v ip > /dev/null 2>&1; then
-		cmd="ip route show"
-	else
-		cmd=route
-	fi
-	set -- \$(\$cmd | grep default)
-	[ "\$2" != via ] && gateway="\$2" || gateway="\$3"
-	printf "%s" \$gateway
-}
-
 start ()
 {
-	local carriers configured dev gateway ifcount infinite interfaces
-	local rc state timeout x
+	local carriers configured dev gateway ifcount infinite
+	local rc state x
 
 	ebegin "Checking to see if the network is online"
 	rc=0
@@ -66,10 +54,15 @@ start ()
 	: \$((timeout -= 1))
  done
  ! \$infinite && [ \$timeout -eq 0 ] && rc=1
- if [ \$rc -eq 0 ] && yesno \${ping_default_gateway:-no}; then
- 	gateway="\$(get_default_gateway)"
- 	if [ -n "\$gateway" ] && ! ping -c 1 \$gateway > /dev/null 2>&1; then
-		rc=1
+ include_ping_test=\${include_ping_test:-\${ping_default_gateway}}
+ if [ -n "\${ping_default_gateway}" ]; then
+ ewarn "ping_default_gateway is deprecated, please use include_ping_test"
+ fi
+ if [ \$rc -eq 0 ] && yesno \${include_ping_test:-no}; then
+ 	ping_test_host="\${ping_test_host:-google.com}"
+ 	if [ -n "\$ping_test_host" ]; then
+		ping -c 1 \$ping_test_host > /dev/null 2>&1
+		rc=\$?
 	fi
  fi
  eend \$rc "The network is offline"
EOF

# Enable the net-online target.
rc-update add net-online default
rc-update -u

