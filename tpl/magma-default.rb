# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure(2) do |config|

  config.vm.boot_timeout = 1800
  # config.vm.box = "lavabit/magma"
  # config.vm.hostname = "magma.build.box"
  config.vm.synced_folder ".", "/vagrant", disabled: true

  config.vm.box_check_update = true

  # config.vm.post_up_message = ""
  config.vm.boot_timeout = 1800
  # config.vm.box_download_checksum = true
  config.vm.boot_timeout = 1800
  # config.vm.box_download_checksum_type = "sha256"

  config.vm.usable_port_range = 20000..30000

  # The box ships with a short script that will clone the git repo and
  # compile the code. This line will trigger that process automatically
  # when the box is provisioned.
  config.vm.provision "shell", run: "always", inline: <<-SHELL
    su -l vagrant -c '/home/vagrant/magma-build.sh'
  SHELL

  # These are the ports currently configured by the sandbox config file and the protocol
  # associated with each. The port numbers and protocols in the sandbox configuration
  # will change over time, and may be different then what is listed below. A particular
  # port may also be different if the corresponding port isn't available on the host system.
  # For a list of the currently configured ports, consult the following file for updates:
  # /home/vagrant/magma-develop/sandbox/etc/magma.sandbox.config

  # Molten
  config.vm.network "forwarded_port", guest: 6000, host: 6000, auto_correct: true

  # Molten IPv6
  config.vm.network "forwarded_port", guest: 6050, host: 6050, auto_correct: true

  # SMTP
  config.vm.network "forwarded_port", guest: 7000, host: 7000, auto_correct: true

  # SMTP IPv6
  config.vm.network "forwarded_port", guest: 7050, host: 7050, auto_correct: true

  # SMTPS
  config.vm.network "forwarded_port", guest: 7500, host: 7500, auto_correct: true

  # DMTP
  config.vm.network "forwarded_port", guest: 7501, host: 7501, auto_correct: true

  # SMTPS IPv6
  config.vm.network "forwarded_port", guest: 7550, host: 7550, auto_correct: true

  # DMTP IPv6
  config.vm.network "forwarded_port", guest: 7551, host: 7551, auto_correct: true

  # POP
  config.vm.network "forwarded_port", guest: 8000, host: 8000, auto_correct: true

  # POP IPv6
  config.vm.network "forwarded_port", guest: 8050, host: 8050, auto_correct: true

  # POP
  config.vm.network "forwarded_port", guest: 8500, host: 8500, auto_correct: true

  # POPS IPv6
  config.vm.network "forwarded_port", guest: 8550, host: 8550, auto_correct: true

  # IMAP
  config.vm.network "forwarded_port", guest: 9000, host: 9000, auto_correct: true

  # IMAP IPv6
  config.vm.network "forwarded_port", guest: 9050, host: 9050, auto_correct: true

  # IMAPS
  config.vm.network "forwarded_port", guest: 9500, host: 9500, auto_correct: true

  # IMAPS IPv6
  config.vm.network "forwarded_port", guest: 9550, host: 9550, auto_correct: true

  # HTTP
  config.vm.network "forwarded_port", guest: 10000, host: 10000, auto_correct: true

  # HTTP IPv6
  config.vm.network "forwarded_port", guest: 10050, host: 10050, auto_correct: true

  # HTTPS
  config.vm.network "forwarded_port", guest: 10500, host: 10500, auto_correct: true

  # HTTPS IPv6
  config.vm.network "forwarded_port", guest: 10550, host: 10550, auto_correct: true

  # Magma will build and run comfortably with 1 CPU and 512MB of RAM
  # but adding a second CPU and increasing the RAM to 2048MB will speed
  # things up considerably during the build process.
  config.vm.provider :hyperv do |v, override|
    v.maxmemory = 2048
    v.memory = 2048
    v.cpus = 2
  end

  config.vm.provider :libvirt do |v, override|
    v.disk_bus = "virtio"
    v.driver = "kvm"
    v.video_vram = 256
    v.memory = 2048
    v.cpus = 2
  end

  config.vm.provider :parallels do |v, override|
    v.customize ["set", :id, "--on-window-close", "keep-running"]
    v.customize ["set", :id, "--startup-view", "headless"]
    v.customize ["set", :id, "--memsize", "2048"]
    v.customize ["set", :id, "--cpus", "2"]
  end

  config.vm.provider :virtualbox do |v, override|
    v.customize ["modifyvm", :id, "--memory", 2048]
    v.customize ["modifyvm", :id, "--vram", 256]
    v.customize ["modifyvm", :id, "--cpus", 2]
    v.gui = false
  end

  ["vmware_fusion", "vmware_workstation", "vmware_desktop"].each do |provider|
    config.vm.provider provider do |v, override|
      v.whitelist_verified = true
      v.gui = false
      v.vmx["cpuid.coresPerSocket"] = "1"
      v.vmx["memsize"] = "2048"
      v.vmx["numvcpus"] = "2"
    end
  end

end
