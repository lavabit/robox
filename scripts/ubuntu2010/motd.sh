#!/bin/bash -eux

sed -i -e "s/motd=\/run\/motd.dynamic/motd=\/etc\/motd/g" /etc/pam.d/sshd
sed -i -e "s/\(.*pam_motd.so.*noupdate.*\)/# \1/g" /etc/pam.d/sshd

sed -i -e "s/motd=\/run\/motd.dynamic/motd=\/etc\/motd/g" /etc/pam.d/login
sed -i -e "s/\(.*pam_motd.so.*noupdate.*\)/# \1/g" /etc/pam.d/login

mkdir -p /root/.cache/
touch /root/.cache/motd.legal-displayed

if [ -d /home/vagrant/ ]; then
  mkdir -p /home/vagrant/.cache/
  touch /home/vagrant/.cache/motd.legal-displayed
  chown vagrant:vagrant /home/vagrant/.cache/ 
  chown vagrant:vagrant /home/vagrant/.cache/motd.legal-displayed
fi

[ -f /etc/apt/apt.conf.d/99update-notifier ] && truncate --size=0 /etc/apt/apt.conf.d/99update-notifier
[ -f /etc/motd ] && truncate --size=0 /etc/motd

systemctl --quiet is-active update-notifier-motd.timer && systemctl stop update-notifier-motd.timer
systemctl --quiet is-active motd-news.timer && systemctl stop motd-news.timer

systemctl --quiet is-enabled update-notifier-motd.timer && systemctl disable update-notifier-motd.timer
systemctl --quiet is-enabled motd-news.timer && systemctl disable motd-news.timer

[ -f /etc/default/motd-news ] && sed -i 's/.*ENABLE.*/ENABLE=0/g' /etc/default/motd-news
