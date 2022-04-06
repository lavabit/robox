
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

Update VirtualBox from 5.2 to 6.1 (will require changes to the NetBSD boot command/timing)  

Generate docker variants for the Ubuntu/Debian/Alpine configurations  
Add upload/delete/release functions to robox.sh  
Add vagrant user password randomization logic to the bundled Vagrantfiles  
Add init based test, and SSH command test to the box test and check script  

## VirtualBox Disks

Enabling the discard/nonrotational options with our VirtualBox configs, appears to improve performance, but only on build robots equipped with SSDs or NVMe drives, and then only if the virtual machine is configured to with VDI virtual disks. This combination allows guests to utilize discard/unmap/trim. However, if a virtual machine is deployed onto traditional magnetic hard disks with discard/nonrotational enabled, performance will drop significantly ( 1/50th of normal in some cases ). 

Furthermore, while Packer appears to use VDI disk image files, when the virtual machine is exported and converted into a Vagrant box, the disk gets converted into the VMDK format. The discard/nonrotational options are preserved, and the result is that when the base box is deployed, it results in a virtual machine with the discard/nonrotational options enabled with an unsupported VMDK virtual disk.

As a result, we currently not using the following options in our Packer config files. 
```
"hard_drive_discard": true,
"hard_drive_nonrotational" : true,
```
A handful of the relevant messages from VirtualBox when a Vagrant box is deployed with this issue.
```
File system of 'generic-debian8-virtualbox/generic-debian8-virtualbox_default_1649216430418_60259/generic-debian8-virtualbox-disk001.vmdk' is xfs
  Format              <string>  = "VMDK" (cb=5)
  Path                <string>  = "generic-debian8-virtualbox/generic-debian8-virtualbox_default_1649216430418_60259/generic-debian8-virtualbox-disk001.vmdk" (cb=154)
VMSetError: /home/vbox/vbox-5.2.44/src/VBox/Storage/VD.cpp(5662) int VDOpen(PVDISK, const char*, const char*, unsigned int, PVDINTERFACE); rc=VERR_VD_DISCARD_NOT_SUPPORTED
MSetError: VD: Backend 'VMDK' does not support discard
AIOMgr: Endpoint for file 'generic-debian8-virtualbox/generic-debian8-virtualbox_default_1649216430418_60259/generic-debian8-virtualbox-disk001.vmdk' (flags 000c0723) created successfully
AIOMgr: generic-debian8-virtualbox/generic-debian8-virtualbox_default_1649216430418_60259/generic-debian8-virtualbox-disk001.vmdk
```
The performance degradation leads to write timeouts, and the logs become filled with messages like the following.
```
VD#0: Write request was active for 36 seconds
VD#0: Aborted write (524288 bytes left) returned rc=VERR_PDM_MEDIAEX_IOREQ_CANCELED
AHCI#0P0: Canceled write at offset 82372182016 (524288 bytes left) returned rc=VERR_PDM_MEDIAEX_IOREQ_CANCELED
```

## Pending Additions

Submit a pull request with your favorite distro.

## Operating System Requests

The following variants of existing builds have been requested, and will be added at a future date, when time allows (or someone submits a pull request).

[CentOS Stream](https://www.centos.org/centos-stream/)  
[Fedora Rawhide](https://fedoraproject.org/wiki/Releases/Rawhide)  
[OpenSUSE Tumbleweed](https://software.opensuse.org/distributions/tumbleweed)  

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
