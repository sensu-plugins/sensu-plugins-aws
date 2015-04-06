# -*- mode: ruby -*-
# vi: set ft=ruby :

require 'json'

VAGRANTFILE_API_VERSION = '2'

# Read in the configuration file for the vagrant environment
config_file = JSON.parse(File.read('../GIR/config/vagrant_config.json'))
vagrant_config = config_file['config']

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  # Standard configurtaion details
  config.vm.box_download_checksum = true
  config.vm.box_download_checksum_type = 'md5'
  config.vm.hostname = 'sensu-plugins-dev'

  # None of the boxes have the chef-client installed,
  # this will install the latest version for provisioning
  config.omnibus.chef_version = :latest

  # Local Berkself configuration
  # This is used only if you add recipes to the boxes below.
  # All dependencies and such for the roles is done with a Berksfile
  # in GIR
  config.berkshelf.enabled = true

  # Box definitions
  # The roles and boxes can be found in the above configuration file
  # in GIR.   If you want to change them you can do so below but any
  # lasting changes should be made against GIR unless they are repo specific
  config.vm.define 'cent5' do |cent5|
    cent5.vm.box = vagrant_config['cent5']['box']
    cent5.vm.provision 'chef_zero' do |chef|
      chef.roles_path = vagrant_config['cent5']['role_path']
      vagrant_config['cent5']['role'].each do |r|
        chef.add_role(r)
      end
      # chef.add_recipe 'apache2'
    end
  end

  config.vm.define 'cent6' do |cent6|
    cent6.vm.box = vagrant_config['cent6']['box']
    cent6.vm.provision 'chef_zero' do |chef|
      chef.roles_path = vagrant_config['cent6']['role_path']
      vagrant_config['cent6']['role'].each do |r|
        chef.add_role(r)
      end
      # chef.add_recipe 'apache2'
    end
  end

  config.vm.define 'cent7' do |cent7|
    cent7.vm.box = vagrant_config['cent7']['box']
    cent7.vm.provision 'chef_zero' do |chef|
      chef.roles_path = vagrant_config['cent7']['role_path']
      vagrant_config['cent7']['role'].each do |r|
        chef.add_role(r)
      end
      # chef.add_recipe 'apache2'
    end
  end

  config.vm.define 'ubuntu14' do |ubuntu14|
    ubuntu14.vm.box = vagrant_config['ubuntu14']['box']
    ubuntu14.vm.provision 'chef_zero' do |chef|
      chef.roles_path = vagrant_config['ubuntu14']['role_path']
      vagrant_config['ubuntu14']['role'].each do |r|
        chef.add_role(r)
      end
    end
  end

  # The bsd boxes have to be configured differently and require some
  # tough love.  Shared folders are not available and using NFS will
  # likely error due to filename length.  You can patch it and use
  # NFS if you really want but that is not supported or reccomended
  # at this time
  #
  # This means that when making changes to GIR you will need to do a reload
  # or possibly a halt/up on the machine to pull in the latest roles and recipes
  config.vm.define 'freebsd92' do |bsd9|
    bsd9.vm.guest = :freebsd
    # The below line is needed for < freebsd9x only
    bsd9.ssh.shell = '/bin/sh'
    bsd9.vm.box = vagrant_config['bsd9']['box']

    # Use rsync as a shared folder
    bsd9.vm.synced_folder '.', '/vagrant', type: 'rsync'
    bsd9.vm.provision 'chef_zero' do |chef|
      chef.synced_folder_type = 'rsync'
      chef.roles_path = vagrant_config['bsd9']['role_path']
      vagrant_config['bsd9']['role'].each do |r|
        chef.add_role(r)
      end
    end
  end

  config.vm.define 'freebsd10' do |bsd10|
    bsd10.vm.guest = :freebsd
    bsd10.vm.box = vagrant_config['bsd10']['box']

    # Use rsync as a shared folder
    bsd10.vm.synced_folder '.', '/vagrant', type: 'rsync'
    bsd10.vm.provision 'chef_zero' do |chef|
      chef.synced_folder_type = 'rsync'
      chef.roles_path = vagrant_config['bsd10']['role_path']
      vagrant_config['bsd10']['role'].each do |r|
        chef.add_role(r)
      end
    end
  end
end
