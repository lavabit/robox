#!/bin/bash

# Delete the OpenSSH host keys, so they get generated when the box is
# provisioned.

rm -f /etc/ssh/ssh_host_key
rm -f /etc/ssh/ssh_host_key.pub

rm -f /etc/ssh/ssh_host_dsa_key
rm -f /etc/ssh/ssh_host_dsa_key.pub

rm -f /etc/ssh/ssh_host_rsa_key
rm -f /etc/ssh/ssh_host_rsa_key.pub

rm -f /etc/ssh/ssh_host_ecdsa_key
rm -f /etc/ssh/ssh_host_ecdsa_key.pub

rm -f /etc/ssh/ssh_host_ed25519_key
rm -f /etc/ssh/ssh_host_ed25519_key.pub
