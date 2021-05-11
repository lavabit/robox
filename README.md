
# Roboxes

Generic base boxes, providing a variety of operating systems, and available across a number of different virtualized platforms.

## Website
https://roboxes.org  

## Vagrant Boxes  
https://app.vagrantup.com/generic  
https://app.vagrantup.com/lavabit  
https://app.vagrantup.com/lineage  

## Docker Images  
https://hub.docker.com/u/roboxes/  
https://hub.docker.com/u/lavabit/  

The templates in this repo require a current version of packer, (1.3.4+) and in some cases, make use of features which haven't been officially merged and/or released yet. Use the res/providers/packer.sh script to build an appropriately patched packer binary.

## Pending Tasks

Add FreeBSD 13.0  
Add Fedora 34  
Add Ubuntu 21.04  
Add Rocky 8.3 / Alma 8.3  

Update VirtualBox from 5.2 to 6.1 (will require changes to the NetBSD boot command/timing)  
Update Packer from 1.6.6 to latest (the preceding task is a prerequisite)  

Generate docker variants for the Ubuntu/Debian/Alpine configurations  
Add upload/delete/release functions to robox.sh  
Add vagrant user password randomization logic to the bundled Vagrantfiles  
Add init based test, and SSH command test to the box test and check script  

## Pending Additions

Submit a pull request with your favorite distro.

## Operating System Requests

The following variants of existing builds have been requested, and will be added at a future date, when time allows (or someone submits a pull request).

[CentOS Stream](https://software.opensuse.org/distributions/tumbleweed)  
[Fedora Rawhide](https://fedoraproject.org/wiki/Releases/Rawhide)  
[OpenSUSE Tumbleweed](https://www.centos.org/centos-stream/)  

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

[Roboxes](https://roboxes.org) is maintained by Ladar Levison, with infrastructure provided by [Lavabit LLC](https://lavabit.com).
