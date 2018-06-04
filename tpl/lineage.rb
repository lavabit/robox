# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|

  config.vm.box = "lavabit/lineage"
  # config.vm.hostname = "lineage.build.box"

  config.vm.synced_folder ".", "/vagrant", disabled: true

  config.vm.box_check_update = true
  config.vm.box_download_checksum = true
  config.vm.box_download_checksum_type = "sha256"

  config.vm.usable_port_range = 20000..30000

  # The box ships with a short script that will clone the git repos and
  # compile the code. This line will trigger that process automatically
  # when the box is provisioned.
  config.vm.provision "shell", run: "always", inline: <<-SHELL
    su -l vagrant /home/vagrant/lineage-build.sh
  SHELL

  # Lineage will build and run comfortably with 1 CPU and 512MB of RAM
  # but adding a second CPU and increasing the RAM to 2048MB will speed
  # things up considerably during the build process.
  config.vm.provider :hyperv do |v, override|
    v.maxmemory = 2048
    v.memory = 2048
    v.cpus = 2
  end

  config.vm.provider :libvirt do |v, override|
    v.driver = "kvm"
    v.video_vram = 256
    v.memory = 2048
    v.cpus = 2
  end

  config.vm.provider :parallels do |v, override|
    v.memory = 2048
    v.cpus = 2
  end

  config.vm.provider :virtualbox do |v, override|
    v.customize ["modifyvm", :id, "--memory", 2048]
    v.customize ["modifyvm", :id, "--vram", 256]
    v.customize ["modifyvm", :id, "--cpus", 2]
    v.customize ["modifyvm", :id, "--usb", "on"]
    v.gui = false
  end

  ["vmware_fusion", "vmware_workstation", "vmware_desktop"].each do |provider|
    config.vm.provider provider do |v, override|
      v.vmx["ethernet0.pcislotnumber"] = "32"
      v.vmx["ethernet0.virtualdev"] = "e1000"
      v.vmx["ethernet0.bsdname"] = "eth0"
      v.vmx["cpuid.coresPerSocket"] = "1"
      v.vmx["memsize"] = "2048"
      v.vmx["numvcpus"] = "2"
      v.gui = false
    end
  end

end
