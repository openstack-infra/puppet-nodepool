# Copyright 2015 2015 IBM
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.

# == Class: nodepool::launcher
#
class nodepool::launcher(
  $statsd_host = undef,
  $statsd_prefix = undef,
  $nodepool_ssh_public_key = undef,
  $launcher_logging_conf_template = 'nodepool/nodepool-launcher.logging.conf.erb',
) {

  if ! defined(File['/home/nodepool/.ssh']) {
    file { '/home/nodepool/.ssh':
      ensure  => directory,
      mode    => '0500',
      owner   => 'nodepool',
      group   => 'nodepool',
      require => User['nodepool'],
    }
  }

  if ($nodepool_ssh_public_key != undef) {
    file { '/home/nodepool/.ssh/id_rsa.pub':
      ensure  => present,
      content => $nodepool_ssh_public_key,
      mode    => '0644',
      owner   => 'nodepool',
      group   => 'nodepool',
      require => File['/home/nodepool/.ssh'],
    }
  }

  file { '/etc/init.d/nodepool-launcher':
    ensure => present,
    mode   => '0555',
    owner  => 'root',
    group  => 'root',
    source => 'puppet:///modules/nodepool/nodepool-launcherv3.init',
  }

  file { '/etc/default/nodepool-launcher':
    ensure  => present,
    content => template('nodepool/nodepool-launcherv3.default.erb'),
    mode    => '0444',
    owner   => 'root',
    group   => 'root',
  }

  file { '/etc/nodepool/launcher-logging.conf':
    ensure  => present,
    mode    => '0444',
    owner   => 'root',
    group   => 'root',
    content => template($launcher_logging_conf_template),
  }

  if ($::operatingsystem == 'Ubuntu') and ($::operatingsystemrelease >= '16.04') {
    # This is a hack to make sure that systemd is aware of the new service
    # before we attempt to start it.
    exec { 'nodepool-launcher-systemd-daemon-reload':
      command     => '/bin/systemctl daemon-reload',
      before      => Service['nodepool-launcher'],
      subscribe   => File['/etc/init.d/nodepool-launcher'],
      refreshonly => true,
    }
  }

  service { 'nodepool-launcher':
    name       => 'nodepool-launcher',
    enable     => true,
    hasrestart => true,
    require    => [
      File['/etc/init.d/nodepool-launcher'],
      File['/etc/default/nodepool-launcher'],
      File['/etc/nodepool/launcher-logging.conf'],
    ],
  }
}
