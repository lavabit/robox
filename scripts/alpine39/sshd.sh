#!/bin/bash -x

sed -i "/^UseDNS.*/d" /etc/ssh/sshd_config
sed -i "/^#UseDNS.*/d" /etc/ssh/sshd_config
sed -i "/^# UseDNS.*/d" /etc/ssh/sshd_config

printf "\nUseDNS no\n" >> /etc/ssh/sshd_config
