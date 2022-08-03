# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure(2) do |config|
  
  config.vm.box = "lineage/lineage"
  config.vm.network :private_network, :auto_config => false, :autostart => false, :libvirt__network_name => "vagrant-libvirt", :libvirt__always_destroy => false

  config.vm.provider :libvirt do |v, override|
    v.qemu_use_session = false
    v.cpus = 8
    v.memory = 24576
    v.video_vram = 256
    v.disk_bus = 'scsi'
    v.disk_device = 'sda'
    v.management_network_keep = true
    v.management_network_autostart = true
    v.cputopology :sockets => '1', :cores => '8', :threads => '1'
    v.disk_driver :bus => 'scsi', :discard => 'ignore', :detect_zeroes => 'off', :io => 'threads', :cache => 'unsafe'
  end

  config.vm.provider :virtualbox do |v, override|
    v.gui = false
    v.customize ["modifyvm", :id, "--memory", 8192]
    v.customize ["modifyvm", :id, "--cpus", 4]
  end

  ["vmware_fusion", "vmware_workstation", "vmware_desktop"].each do |provider|
    config.vm.provider provider do |v, override|
      v.gui = false
      v.vmx["memsize"] = "8192"
      v.vmx["numvcpus"] = "4"
      v.vmx["cpuid.coresPerSocket"] = "1"
    end
  end
  
end


