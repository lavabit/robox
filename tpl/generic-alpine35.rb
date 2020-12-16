# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure(2) do |config|

  config.vm.boot_timeout = 1800
  config.vm.synced_folder ".", "/vagrant", disabled: true

  config.vm.box_check_update = true

  # config.vm.post_up_message = ""
  config.vm.boot_timeout = 1800
  # config.vm.box_download_checksum = true
  config.vm.boot_timeout = 1800
  # config.vm.box_download_checksum_type = "sha256"

  # config.vm.provision "shell", run: "always", inline: <<-SHELL
  # SHELL

  # Adding a second CPU and increasing the RAM to 2048MB will speed
  # things up considerably should you decide to do anythinc with this box.
  config.vm.provider :hyperv do |v, override|
    v.cpus = 2
    v.memory = 2048
    v.maxmemory = 2048
  end

  config.vm.provider :libvirt do |v, override|
    v.cpus = 2
    v.memory = 2048
    v.driver = "kvm"
    v.video_vram = 256
    v.disk_bus = "scsi"
    if Vagrant.version?("< 2.2.6") && !Vagrant.has_plugin?("vagrant-alpine")
      override.trigger.before :up do |t|
        t.warn = "Setting OS type to 'ALT Linux' as a workaround, which might break guest OS specific features.\nPlease upgrade to Vagrant 2.2.6 or (if Vagrant can't be upgraded) install the 'vagrant-alpine' plugin if issues arise."
      end
      override.vm.guest = :alt
    end
    v.channel :type => 'unix', :target_name => 'org.qemu.guest_agent.0', :target_type => 'virtio'
  end

  config.vm.provider :parallels do |v, override|
    v.customize ["set", :id, "--on-window-close", "keep-running"]
    v.customize ["set", :id, "--startup-view", "headless"]
    v.customize ["set", :id, "--memsize", "2048"]
    v.customize ["set", :id, "--cpus", "2"]
  end

  config.vm.provider :virtualbox do |v, override|
    v.gui = false
    v.customize ["modifyvm", :id, "--vram", 256]
    v.customize ["modifyvm", :id, "--cpus", 2]
    v.customize ["modifyvm", :id, "--memory", 2048]
  end

  ["vmware_fusion", "vmware_workstation", "vmware_desktop"].each do |provider|
    config.vm.provider provider do |v, override|
      v.whitelist_verified = true
      v.functional_hgfs = false
      v.gui = false
      v.vmx["cpuid.coresPerSocket"] = "1"
      v.vmx["memsize"] = "2048"
      v.vmx["numvcpus"] = "2"
    end
  end

end
