# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure(2) do |config|

  config.vm.box = "lavabit/magma-developer"
  config.vm.network :private_network, :auto_config => false, :autostart => false, :libvirt__network_name => "default", :libvirt__always_destroy => false

  config.vm.provider :libvirt do |v, override|
    v.driver = "kvm"
    v.video_vram = 256
    v.memory = 4096
    v.cpus = 4
    v.management_network_keep = true
    v.management_network_autostart = true
  end

  config.vm.provider :hyperv do |v, override|
    v.maxmemory = 4096
    v.memory = 4096
    v.cpus = 4
  end

  config.vm.provider :virtualbox do |v, override|
    v.gui = true
    v.customize ["modifyvm", :id, "--memory", 4096]
    v.customize ["modifyvm", :id, "--cpus", 4]
  end

  ["vmware_fusion", "vmware_workstation", "vmware_desktop"].each do |provider|
    config.vm.provider provider do |v, override|
      v.gui = true
      v.vmx["memsize"] = "4096"
      v.vmx["numvcpus"] = "4"
      v.vmx["cpuid.coresPerSocket"] = "1"
    end
  end

end
