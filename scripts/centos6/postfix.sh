#!/bin/bash -eux

retry() {
  local COUNT=1
  local DELAY=0
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

# The postfix server for message relays. The checkpolicy, policycoreutils and the-
# policycoreutils-python packages are needed to compile the selinux module below.
retry yum --assumeyes install postfix checkpolicy policycoreutils policycoreutils-python

# Postfix opportunistic TLS relay.
printf "smtp_tls_CAfile = /etc/pki/tls/certs/ca-bundle.crt\n" >> /etc/postfix/main.cf
printf "smtp_tls_ciphers = high\n" >> /etc/postfix/main.cf
printf "smtp_tls_loglevel = 2\n" >> /etc/postfix/main.cf
printf "smtp_tls_mandatory_ciphers = medium\n" >> /etc/postfix/main.cf
printf "smtp_tls_mandatory_protocols = SSLv3 TLSv1\n" >> /etc/postfix/main.cf
printf "smtp_tls_protocols = !SSLv2 !SSLv3\n" >> /etc/postfix/main.cf
printf "smtp_tls_security_level = may\n" >> /etc/postfix/main.cf
printf "tls_daemon_random_bytes = 128\n" >> /etc/postfix/main.cf
printf "tls_random_bytes = 255\n" >> /etc/postfix/main.cf
printf "tls_random_reseed_period = 1800s\n\n" >> /etc/postfix/main.cf

# Postfix size limits.
printf "body_checks_size_limit = 134217728\n"
printf "mailbox_size_limit = 0\n"
printf "message_size_limit = 134217728\n"
printf "virtual_mailbox_limit = 0\n\n"

# Configure the postfix hostname and origin parameters.
printf "\ninet_interfaces = localhost\n" >> /etc/postfix/main.cf
printf "inet_protocols = ipv4\n" >> /etc/postfix/main.cf
printf "myhostname = relay.magma.builder\n" >> /etc/postfix/main.cf
printf "myorigin = magma.builder\n" >> /etc/postfix/main.cf
printf "transport_maps = hash:/etc/postfix/transport\n" >> /etc/postfix/main.cf

# Configure postfix to listen for relays on port 2525 so it doesn't conflict with magma.
sed -i -e "s/^smtp\([ ]*inet\)/127.0.0.1:2525\1/" /etc/postfix/master.cf

mkdir -p $HOME/pp && cd $HOME/pp

cat <<-EOF > postfix_relay_host.te
module postfix_relay_host 1.0;

require {
    type postfix_master_t;
    type port_t;
    class tcp_socket name_bind;
}

#============= postfix_master_t ==============

allow postfix_master_t port_t:tcp_socket name_bind;
EOF

# Modify the selinux rules so that postfix may bind to port 2525.
checkmodule -M -m -o postfix_relay_host.mod postfix_relay_host.te
semodule_package -o postfix_relay_host.pp -m postfix_relay_host.mod
semodule -i postfix_relay_host.pp

# Cleanup the policy files.
cd $HOME && rm --recursive --force $HOME/pp

# Setup logrotate so it only stores 7 days worth of logs.
cat <<-EOF > /etc/logrotate.d/postfix
/var/log/maillog {
	daily
	rotate 7
	missingok
	create 0600 root root
	postrotate
        	/sbin/service rsyslog reload  2> /dev/null > /dev/null || true
        endscript
}
EOF

# Fix the SELinux context for the postfix logrotate config.
chcon system_u:object_r:etc_t:s0 /etc/logrotate.d/postfix

# Remove the existing logrotation directive.
sed -i -e "/maillog/d" /etc/logrotate.d/syslog

#printf "\nmagma.builder         smtp:[127.0.0.1]:7000\n" >> /etc/postfix/transport
#printf "magmadaemon.com         smtp:[127.0.0.1]:7000\n" >> /etc/postfix/transport
postmap /etc/postfix/transport

# So it gets started automatically.
chkconfig postfix on && service postfix start
