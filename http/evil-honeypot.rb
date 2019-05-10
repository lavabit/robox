d-i base-installer/kernel/override-image string linux-server
d-i keyboard-configuration/xkb-keymap select us
d-i time/zone string US/Pacific
d-i debian-installer/locale string en_US
d-i debian-installer/add-kernel-opts string net.ifnames=0 biosdevname=0 
d-i finish-install/reboot_in_progress note
d-i grub-installer/bootdev string default
d-i partman-auto/method string regular
d-i partman-auto/expert_recipe string \
        scheme ::                     \
        512 0 512 ext4                \
                $primary{ }           \
                $bootable{ }          \
                method{ format }      \
                format{ }             \
                use_filesystem{ }     \
                filesystem{ ext4 }    \
                mountpoint{ /boot } . \
        200% 0 200% linux-swap        \
                $primary{ }           \
                method{ swap }        \
                format{ } .           \
        1 0 -1 ext4                   \
                $primary{ }           \
                method{ format }      \
                format{ }             \
                use_filesystem{ }     \
                filesystem{ ext4 }    \
                mountpoint{ / } .
d-i partman-partitioning/confirm_write_new_label boolean true
d-i partman/choose_partition select finish
d-i partman/confirm boolean true
d-i partman/confirm_nooverwrite boolean true
d-i passwd/root-login boolean true
d-i passwd/root-password password vagrant
d-i passwd/root-password-again password vagrant
d-i passwd/user-fullname string vagrant
d-i passwd/user-uid string 1000
d-i passwd/user-password password vagrant
d-i passwd/user-password-again password vagrant
d-i passwd/username string vagrant
d-i user-setup/allow-password-weak boolean true
d-i user-setup/encrypt-home boolean false
d-i netcfg/hostname string ubuntu1604.localdomain

tasksel tasksel/first multiselect standard, server
d-i pkgsel/include string curl openssh-server sudo sed linux-tools-$(uname -r) linux-cloud-tools-$(uname -r) linux-cloud-tools-common linux-cloud-tools-generic linux-cloud-tools-virtual
d-i pkgsel/install-language-support boolean false
d-i pkgsel/language-packs multiselect en
d-i pkgsel/update-policy select none
d-i pkgsel/upgrade select none

# Remove the following when the mirrors no longer support 16.04 updates.
choose-mirror-bin mirror/http/proxy string

#d-i mirror/http/proxy string
#d-i mirror/country string manual
#d-i mirror/http/hostname string old-releases.ubuntu.com
#d-i mirror/http/directory string /ubuntu

#d-i apt-setup/security_host string old-releases.ubuntu.com
#d-i apt-setup/security_path string /ubuntu

# Add the following when the mirrors no longer support 16.04 updates.
#; \
#sed -i -e "s/security.ubuntu.com/old-releases.ubuntu.com/g" /target/etc/apt/sources.list ; \
#sed -i -e "s/us.archive.ubuntu.com/old-releases.ubuntu.com/g" /target/etc/apt/sources.list

d-i preseed/late_command string                                                   \
  sed -i -e "s/.*PermitRootLogin.*/PermitRootLogin yes/g" /target/etc/ssh/sshd_config
