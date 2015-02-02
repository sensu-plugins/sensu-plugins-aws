# -*- mode: ruby -*-
# vi: set ft=ruby :

VAGRANTFILE_API_VERSION = '2'

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|

  config.vm.box = 'chef/centos-6.6'
  config.vm.box_download_checksum = true
  config.vm.box_download_checksum_type = 'md5'
  config.vm.hostname = 'sensu-plugins-dev'

  script = <<EOF
  #sudo yum update -y
  sudo yum groupinstall -y development
  sudo yum install -y vim nano
  sudo yum install -y ImagicMagic ImageMagick-devel mysql-devel # needed for bundle install
  gpg2 --keyserver hkp://keys.gnupg.net --recv-keys D39DC0E3
  curl -L get.rvm.io | bash -s stable
  source /home/vagrant/.rvm/scripts/rvm
  rvm reload
  rvm install 1.9.3
  rvm install 2.1.4
  #rvm install 2.0.0
  rvm use 1.9.3@sensu_plugins --create
  #rvm use 2.0.0@sensu_plugins --create
  rvm use 2.1.4@sensu_plugins --create
  rvm use 2.1.4@sensu_plugins --default
EOF

  config.vm.provision 'shell', inline: script, privileged: false
end
