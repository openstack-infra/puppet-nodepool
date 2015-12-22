# Copyright 2012-2013 Hewlett-Packard Development Company, L.P.
# Copyright 2012 Antoine "hashar" Musso
# Copyright 2012 Wikimedia Foundation Inc.
# Copyright 2013 OpenStack Foundation
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

# == Class: nodepool
#
class nodepool (
  $mysql_root_password,
  $mysql_password,
  $nodepool_ssh_private_key,
  $git_source_repo = 'https://git.openstack.org/openstack-infra/nodepool',
  $revision = 'master',
  $statsd_host = undef,
  $vhost_name = $::fqdn,
  $image_log_document_root = '/var/log/nodepool/image',
  $enable_image_log_via_http = false,
  $environment = {},
  # enable sudo for nodepool user. Useful for using dib with nodepool
  $sudo = true,
  $scripts_dir = undef,
  $elements_dir = undef,
  $logging_conf_template = 'nodepool/nodepool.logging.conf.erb',
  $jenkins_masters = [],
) {

  validate_bool($builder_workers)

  include nodepool::install

  class { '::mysql::server':
    config_hash => {
      'root_password'  => $mysql_root_password,
      'default_engine' => 'InnoDB',
      'bind_address'   => '127.0.0.1',
    }
  }

  include ::mysql::server::account_security

  mysql::db { 'nodepool':
    user     => 'nodepool',
    password => $mysql_password,
    host     => 'localhost',
    grant    => ['all'],
    charset  => 'utf8',
    require  => [
      Class['mysql::server'],
      Class['mysql::server::account_security'],
    ],
  }

  file { '/etc/mysql/conf.d/max_connections.cnf':
    ensure  => present,
    content => "[server]\nmax_connections = 8192\n",
    mode    => '0444',
    owner   => 'root',
    group   => 'root',
  }

  if ($scripts_dir != undef) {
    file { '/etc/nodepool/scripts':
      ensure  => directory,
      owner   => 'root',
      group   => 'root',
      mode    => '0755',
      recurse => true,
      purge   => true,
      force   => true,
      require => File['/etc/nodepool'],
      source  => $scripts_dir,
    }
  }

  if ($elements_dir != undef) {
    file { '/etc/nodepool/elements':
      ensure  => directory,
      owner   => 'root',
      group   => 'root',
      mode    => '0755',
      recurse => true,
      purge   => true,
      force   => true,
      require => File['/etc/nodepool'],
      source  => $elements_dir
    }
  }

  file { '/etc/default/nodepool':
    ensure  => present,
    content => template('nodepool/nodepool.default.erb'),
    mode    => '0444',
    owner   => 'root',
    group   => 'root',
  }


  file { '/home/nodepool/.ssh':
    ensure  => directory,
    mode    => '0500',
    owner   => 'nodepool',
    group   => 'nodepool',
    require => User['nodepool'],
  }

  file { '/home/nodepool/.ssh/id_rsa':
    ensure  => present,
    content => $nodepool_ssh_private_key,
    mode    => '0400',
    owner   => 'nodepool',
    group   => 'nodepool',
    require => File['/home/nodepool/.ssh'],
  }

  file { '/home/nodepool/.ssh/config':
    ensure  => present,
    source  => 'puppet:///modules/nodepool/ssh.config',
    mode    => '0440',
    owner   => 'nodepool',
    group   => 'nodepool',
    require => File['/home/nodepool/.ssh'],
  }

  file { '/etc/nodepool/logging.conf':
    ensure  => present,
    mode    => '0444',
    owner   => 'root',
    group   => 'root',
    content => template($logging_conf_template),
  }

  validate_array($jenkins_masters)
  file { '/etc/nodepool/secure.conf':
    ensure  => present,
    owner   => 'nodepool',
    group   => 'root',
    mode    => '0400',
    content => template('nodepool/secure.conf.erb'),
    require => [
      File['/etc/nodepool'],
      User['nodepool'],
    ],
  }

  file { '/etc/init.d/nodepool':
    ensure => present,
    mode   => '0555',
    owner  => 'root',
    group  => 'root',
    source => 'puppet:///modules/nodepool/nodepool.init',
  }

  service { 'nodepool':
    name       => 'nodepool',
    enable     => true,
    hasrestart => true,
    require    => File['/etc/init.d/nodepool'],
  }

  if $enable_image_log_via_http == true {
    # Setup apache for image log access
    include ::httpd

    ::httpd::vhost { $vhost_name:
      port     => 80,
      priority => '50',
      docroot  => 'MEANINGLESS_ARGUMENT',
      template => 'nodepool/nodepool-log.vhost.erb',
    }
  }

  if $image_log_document_root != '/var/log/nodepool' {
    file { $image_log_document_root:
      ensure  => directory,
      mode    => '0755',
      owner   => 'nodepool',
      group   => 'nodepool',
      require => [
        User['nodepool'],
        File['/var/log/nodepool'],
      ],
    }
  }

  if $sudo == true {
    $sudo_file_ensure = present
  }
  else {
    $sudo_file_ensure = absent
  }
  file { '/etc/sudoers.d/nodepool-sudo':
    ensure => $sudo_file_ensure,
    source => 'puppet:///modules/nodepool/nodepool-sudo.sudo',
    owner  => 'root',
    group  => 'root',
    mode   => '0440',
  }

}
