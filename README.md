
# Roboxes

Generic base boxes, providing a variety of operating systems, and available across a number of different virtualized platforms.

## Website
https://roboxes.org  

## Vagrant Boxes  
https://app.vagrantup.com/generic  
https://app.vagrantup.com/lavabit  
https://app.vagrantup.com/lineage  

## Docker Images  
https://hub.docker.com/r/lavabit/  

Note, the generic templates are being refactored to use the split function. This requires packer v1.2.6+.

## Pending Tasks

Merge duplicate magma and lineage configurations
Remove ejection logic from Hyper-V configurations
Troubleshoot Dragonfly/NetBSD on Hyper-V
Add retry function to scripts and wrap yum/apt/apk/pacman/etc (prototype in upload.sh already)
Automatically retry failed box builds
Generate docker variants for the RHEL/Oracle/Ubuntu/Debian/Alpine configurations
Create standalone release script
Add upload/delete/release functions to robox.sh
Add vagrant user password randomization logic to the bundled Vagrantfiles
Add init based test, and SSH command test to the box test and check script
Add an explicit storage path to the Hyper-V templates
Update the parallels/vitualbox configs so they use the new cpus/memory template keys
Consolidate magma/docker post processors by making better use of the split function

## Pending Additions

[Devuan 8](https://devuan.org/)  
[HardenedBSD 12](https://hardenedbsd.org/)  
[Debian 10 (Feb/Mar)](https://wiki.debian.org/DebianBuster)  
[Ubuntu 19.04 (Feb/Mar)](https://wiki.ubuntu.com/DiscoDingo)  

## Operating System Requests

The following operating systems have been requested by a member of the robox community, but require a volunteer, so they can be incorporated into the robox workflow.

[Haiku](https://www.haiku-os.org/get-haiku/)  
[Minix](https://www.minix3.org/)  
[Parrot](https://www.parrotsec.org/)  
[SmartOS](https://www.joyent.com/smartos)

## Operating System Candidates

The following operating systems are on my personal list, but haven't been added because of various resource contraints.

Manjaro  
Mint  
OpenSolaris  
OpenSUSE Leap v15 (already building v42.3)  
Oracle v6 (already building v7)  
Scientific Linux v6/v7  
Slackware  

MacOS  
ReactOS  
Windows  

Tails  
Kali  

## Donate

The roboxes are maintained by volunteers, and provided for free. As such we rely on donations to cover the cost of the hardware, and bandwidth. If you find this project useful, and would like to see it grow, please help by making a Bitcoin, Bitcoin Cash, Monero or [monetary donation](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=99THGS6F4HGLU&source=url). If you represent a public cloud, and would like to provide infrastructure support, please contact us directly, or open a ticket.

Monero
8B3BsNGvpT3SAkMCa672FaCjRfouqnwtxMKiZrMx27ry1KA7aNy5J4kWuJBBRfwzsKZrTvud2wrLH2uvaDBdBw9cSrVRzxC

Bitcoin
3NKSTPEeTGmuA95CGGqnyi3zPASSApLZbE

Bitcoin Cash
qqxyedtn68jg84w4mkd3vsw2nu6pgkydnudza0ed0m
