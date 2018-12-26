
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
Add retry function to scripts and wrap yum/apt/apk/pacman/etc
Automatically retry failed box builds
Generate docker variants for the RHEL/Oracle/Ubuntu/Debian/Alpine configurations
Create standalone release script
Add upload/delete/release functions to robox.sh
Add vagrant user password randomization logic to the bundled Vagrantfiles
Add init based test, and SSH command test to the box test and check script

## Pending Additions

Devuan 8
HardenedBSD 12
Debian 10 (Feb/Mar)
Ubuntu 19.04 (Feb/Mar)

## Operating System Candidates

Manjaro  
Mint  
OpenSolaris  
OpenSUSE Leap v15 (already building v42.3)  
Oracle 6 (already building v7)  
Scientific Linux v6/v7  
Slackware  

MacOS  
ReactOS  
Windows  

Tails  
Kali  
Parrot
