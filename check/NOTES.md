
# Use the latest version of the vagrant-libvirt code.
rm -rf vagrant.d vagrant-libvirt ; ./check.sh plugin-libvirt ; source env.sh && git clone https://github.com/vagrant-libvirt/vagrant-libvirt.git && cd vagrant-libvirt && git tag 0.9.1 && /opt/vagrant/embedded/bin/gem build vagrant-libvirt.gemspec && vagrant plugin install vagrant-libvirt-0.9.1.gem && cd .. && vagrant plugin list

# Check that the default vagrant-libvirt network is ready.
virsh --connect=qemu:///system net-list --all

# From a fresh session, run the following.
cd check/ && ./check.sh generic-libvirt 



cat <<-EOF > /etc/libvirt/qemu/networks/vagrant-libvirt.xml
<!--
WARNING: THIS IS AN AUTO-GENERATED FILE. CHANGES TO IT ARE LIKELY TO BE
OVERWRITTEN AND LOST. Changes to this xml configuration should be made using:
  virsh net-edit vagrant-libvirt
or other application using the libvirt API.
-->

<network ipv6='yes'>
  <name>vagrant-libvirt</name>
  <uuid>27322724-a97c-4b42-b6d0-f32df6ec20ef</uuid>
  <forward mode='nat'/>
  <bridge name='virbr1' stp='on' delay='0'/>
  <mac address='52:54:00:7d:e1:0e'/>
  <ip address='192.168.121.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.121.1' end='192.168.121.254'/>
    </dhcp>
  </ip>
</network>
EOF

cd /etc/libvirt/qemu/networks/autostart/
ln -s ../vagrant-libvirt.xml vagrant-libvirt.xml



