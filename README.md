
# Roboxes

Generic base boxes, providing a variety of operating systems, and available across a number of different virtualized platforms.

## Website
https://roboxes.org  

## Vagrant Boxes  
https://app.vagrantup.com/generic  
https://app.vagrantup.com/lavabit  
https://app.vagrantup.com/lineage  

## Podman / Docker Images  
https://hub.docker.com/u/roboxes/  
https://hub.docker.com/u/lavabit/  
or   
https://quay.io/organization/roboxes  
https://quay.io/organization/lavabit  

## Pending Additions

Submit a pull request with your favorite distro.

## Pending Tasks

Update VirtualBox from 5.2 to 6.1 (will require changes to the NetBSD boot command/timing)  

Generate docker variants for the Ubuntu/Debian/Alpine configurations  
Create arm images for distros/platforms with support (WE NEED A HARDWARE DONATION TO MAKE THIS HAPPEN)  
Add upload/delete/release functions to robox.sh  
Add vagrant user password randomization logic to the bundled Vagrantfiles  
Add init based test, and SSH command test to the box test and check script  

## Building a Box

To build a specific box, run the following:  

```bash
git clone https://github.com/lavabit/robox && cd robox
./robox.sh box generic-BOX-PROVIDER
```

Replace `BOX` with one of the following values:  `[alma8|alpine310|alpine311|alpine312|alpine313|alpine314|alpine315|alpine35|alpine36|alpine37|alpine38|alpine39|arch|centos6|centos7|centos8|debian10|debian11|debian8|debian9|devuan1|devuan2|devuan3|devuan4|dragonflybsd5|dragonflybsd6|fedora25|fedora26|fedora27|fedora28|fedora29|fedora30|fedora31|fedora32|fedora33|fedora34|fedora35|fedora36|freebsd11|freebsd12|freebsd13|gentoo|hardenedbsd11|hardenedbsd12|hardenedbsd13|netbsd8|netbsd9|openbsd6|openbsd7|opensuse15|opensuse42|oracle7|oracle8|rhel6|rhel7|rhel8|rocky8|ubuntu1604|ubuntu1610|ubuntu1704|ubuntu1710|ubuntu1804|ubuntu1810|ubuntu1904|ubuntu1910|ubuntu2004|ubuntu2010|ubuntu2104|ubuntu2110|ubuntu2204]` and replace `PROVIDER` provider with `[docker|hyperv|libvirt|parallels|virtualbox|vmware]`.

The above presumes you already have [`packer`](https://www.packer.io/) and the target provider installed. The `res/providers/providers.sh` script can be used to configure a system appropriately, and install the various providers. Currently the script only works on RHEL 7 or CentOS 7, but the steps/commands should work on other Linux distros with appropriate adjustments. 

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

## Donate

The roboxes are maintained by volunteers, and provided for free. As such we rely on donations to cover the cost of the hardware, and bandwidth. If you find this project useful, and would like to see it grow, please help by making a Bitcoin, Bitcoin Cash, Monero or [monetary donation](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=99THGS6F4HGLU&source=url). If you represent a public cloud, and would like to provide infrastructure support, please contact us directly, or open a ticket.

Monero
8B3BsNGvpT3SAkMCa672FaCjRfouqnwtxMKiZrMx27ry1KA7aNy5J4kWuJBBRfwzsKZrTvud2wrLH2uvaDBdBw9cSrVRzxC

Bitcoin
3NKSTPEeTGmuA95CGGqnyi3zPASSApLZbE

Bitcoin Cash
qqxyedtn68jg84w4mkd3vsw2nu6pgkydnudza0ed0m

[Roboxes](https://roboxes.org) is maintained by Ladar Levison, with infrastructure provided by [Lavabit LLC](https://lavabit.com).
