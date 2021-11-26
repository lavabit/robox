# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure(2) do |config|

  config.vm.box = "generic/alma8"

  config.ssh.forward_x11 = true
  config.ssh.forward_agent = true

  config.vm.provider :libvirt do |v, override|
    v.driver = "kvm"
    v.video_vram = 256
    v.memory = 2048
    v.cpus = 2
  end

  config.vm.provider :hyperv do |v, override|
    v.maxmemory = 2048
    v.memory = 2048
    v.cpus = 2
  end

  config.vm.provider :virtualbox do |v, override|
    v.gui = false
    v.customize ["modifyvm", :id, "--memory", 2048]
    v.customize ["modifyvm", :id, "--cpus", 2]
  end

  ["vmware_fusion", "vmware_workstation", "vmware_desktop"].each do |provider|
    config.vm.provider provider do |v, override|
      v.gui = false
      v.vmx["memsize"] = "2048"
      v.vmx["numvcpus"] = "2"
      v.vmx["cpuid.coresPerSocket"] = "1"
    end
  end

  config.vm.provision "shell", inline: <<-SHELL
    sudo sed -i 's/.*X11Forwarding.*/X11Forwarding yes/g' /etc/ssh/sshd_config
    sudo sed -i 's/.*X11UseLocalhost.*/X11UseLocalhost no/g' /etc/ssh/sshd_config
    sudo sed -i 's/.*X11DisplayOffset.*/X11DisplayOffset 10/g' /etc/ssh/sshd_config
    sudo systemctl restart sshd.service
  SHELL

end
