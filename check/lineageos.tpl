# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure(2) do |config|

  config.vm.box = "lineageos/lineage"

  config.vm.provider :libvirt do |v, override|
    v.driver = "kvm"
    v.video_vram = 256
    v.memory = 24576
    v.cpus = 10
    v.storage  :bus => 'scsi', :discard => 'ignore', :detect_zeroes => 'off', :io => 'threads', :cache => 'unsafe'
  end

  config.vm.provider :virtualbox do |v, override|
    v.gui = false
    v.customize ["modifyvm", :id, "--memory", 8192]
    v.customize ["modifyvm", :id, "--cpus", 4]
  end

  ["vmware_fusion", "vmware_workstation", "vmware_desktop"].each do |provider|
    config.vm.provider provider do |v, override|
      v.gui = false
      v.vmx["memsize"] = "8196"
      v.vmx["numvcpus"] = "4"
      v.vmx["cpuid.coresPerSocket"] = "1"
    end
  end

end
