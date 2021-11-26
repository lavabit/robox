# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure(2) do |config|

  config.vm.box = "generic/alpine37"
  #config.vm.guest = :alpine

  config.vm.provider :libvirt do |v, override|
    v.driver = "kvm"
    v.video_vram = 256
    v.memory = 2048
    v.cpus = 2
    v.channel :type => 'unix', :target_name => 'org.qemu.guest_agent.0', :target_type => 'virtio'
  end

  config.vm.provider :hyperv do |v, override|
    v.maxmemory = 2048
    v.memory = 2048
    v.cpus = 2
  end

  config.vm.provider :virtualbox do |v, override|
    v.gui = false
    v.functional_vboxsf = false
    v.check_guest_additions = false
    v.customize ["modifyvm", :id, "--memory", 2048]
    v.customize ["modifyvm", :id, "--cpus", 2]
  end

  ["vmware_fusion", "vmware_workstation", "vmware_desktop"].each do |provider|
    config.vm.provider provider do |v, override|
      v.gui = false
      v.functional_hgfs = false
      v.vmx["memsize"] = "2048"
      v.vmx["numvcpus"] = "2"
      v.vmx["cpuid.coresPerSocket"] = "1"
    end
  end

end
