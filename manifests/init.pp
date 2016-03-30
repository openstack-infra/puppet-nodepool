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
  $builder_logging_conf_template = 'nodepool/nodepool-builder.logging.conf.erb',
  $elements_dir                  = undef,
  $enable_image_log_via_http     = false,
  $environment                   = {},
  $git_source_repo               = 'https://git.openstack.org/openstack-infra/nodepool',
  $image_log_document_root       = '/var/log/nodepool/image',
  $image_log_periodic_cleanup    = false,
  $jenkins_masters               = [],
  $logging_conf_template         = 'nodepool/nodepool.logging.conf.erb',
  $mysql_db_name                 = 'nodepool',
  $mysql_host                    = 'localhost',
  $mysql_user_name               = 'nodepool',
  $nodepool_ssh_private_key      = undef,
  $revision                      = 'master',
  $scripts_dir                   = undef,
  $statsd_host                   = undef,
  # by default statsd used 8125 port
  $statsd_port                   = undef,
  # enable sudo for nodepool user. Useful for using dib with nodepool
  $sudo                          = true,
  $user                          = 'nodepool',
  $vhost_name                    = $::fqdn,
) {

  $packages = [
    'build-essential',
    'libffi-dev',
    'libssl-dev',
    'libgmp-dev',         # transitive dep of paramiko
    # xml2 and xslt are needed to build python lxml.
    'libxml2-dev',
    'libxslt-dev',
  ]

  package { $packages :
    ensure  => present,
  }

  group { $user :
    ensure => present,
  }

  user { $user :
    ensure     => present,
    home       => '/home/nodepool',
    shell      => '/bin/bash',
    gid        => $user,
    managehome => true,
    require    => Group[$user],
  }

  vcsrepo { '/opt/nodepool':
    ensure   => latest,
    provider => git,
    revision => $revision,
    source   => $git_source_repo,
  }

  include ::diskimage_builder

  include ::pip
  exec { 'install_nodepool' :
    command     => 'pip install -U /opt/nodepool',
    path        => '/usr/local/bin:/usr/bin:/bin/',
    refreshonly => true,
    subscribe   => Vcsrepo['/opt/nodepool'],
    require     => [
      Class['pip'],
      Package['build-essential'],
      Package['libffi-dev'],
      Package['libssl-dev'],
      Package['libxml2-dev'],
      Package['libxslt-dev'],
      Package['libgmp-dev'],
    ],
  }

  file { '/etc/nodepool' :
    ensure => directory,
  }

  if ($scripts_dir) {
    file { '/etc/nodepool/scripts' :
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

  if ($elements_dir) {
    file { '/etc/nodepool/elements' :
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

  file { '/etc/default/nodepool' :
    ensure  => present,
    content => template('nodepool/nodepool.default.erb'),
    mode    => '0444',
    owner   => 'root',
    group   => 'root',
  }

  # used for storage of d-i-b images in non-ephemeral partition
  file { '/opt/nodepool_dib' :
    ensure  => directory,
    mode    => '0755',
    owner   => $user,
    group   => $user,
    require => User[$user],
  }

  # used for storage of d-i-b cached data
  file { '/opt/dib_cache' :
    ensure  => directory,
    mode    => '0755',
    owner   => $user,
    group   => $user,
    require => User[$user],
  }

  # used as TMPDIR during d-i-b image builds
  file { '/opt/dib_tmp' :
    ensure  => directory,
    mode    => '0755',
    owner   => $user,
    group   => $user,
    require => User[$user],
  }

  file { '/var/log/nodepool' :
    ensure  => directory,
    mode    => '0755',
    owner   => $user,
    group   => $user,
    require => User[$user],
  }

  file { '/var/run/nodepool' :
    ensure  => directory,
    mode    => '0755',
    owner   => $user,
    group   => $user,
    require => User[$user],
  }

  file { '/home/nodepool/.ssh' :
    ensure  => directory,
    mode    => '0500',
    owner   => $user,
    group   => $user,
    require => User[$user],
  }

  if($nodepool_ssh_private_key) {
    file { '/home/nodepool/.ssh/id_rsa' :
      ensure  => present,
      content => $nodepool_ssh_private_key,
      mode    => '0400',
      owner   => $user,
      group   => $user,
      require => File['/home/nodepool/.ssh'],
    }
  }

  file { '/home/nodepool/.ssh/config' :
    ensure  => present,
    source  => 'puppet:///modules/nodepool/ssh.config',
    mode    => '0440',
    owner   => $user,
    group   => $user,
    require => File['/home/nodepool/.ssh'],
  }

  file { '/etc/nodepool/logging.conf' :
    ensure  => present,
    mode    => '0444',
    owner   => 'root',
    group   => 'root',
    content => template($logging_conf_template),
  }

  validate_array($jenkins_masters)
  file { '/etc/nodepool/secure.conf' :
    ensure  => present,
    owner   => $user,
    group   => $user,
    mode    => '0400',
    content => template('nodepool/secure.conf.erb'),
    require => [
      File['/etc/nodepool'],
      User[$user],
    ],
  }

  file { '/etc/init.d/nodepool' :
    ensure => present,
    mode   => '0555',
    owner  => 'root',
    group  => 'root',
    source => 'puppet:///modules/nodepool/nodepool.init',
  }

  service { 'nodepool' :
    name       => 'nodepool',
    enable     => true,
    hasrestart => true,
    require    => File['/etc/init.d/nodepool'],
  }

  if ($enable_image_log_via_http) {
    # Setup apache for image log access
    include ::httpd

    ::httpd::vhost { $vhost_name:
      port     => 80,
      priority => '50',
      docroot  => 'MEANINGLESS_ARGUMENT',
      template => 'nodepool/nodepool-log.vhost.erb',
    }
  }

  if ($image_log_document_root != '/var/log/nodepool') {
    file { $image_log_document_root :
      ensure  => directory,
      mode    => '0755',
      owner   => $user,
      group   => $user,
      require => [
        User[$user],
        File['/var/log/nodepool'],
      ],
    }
  }

  # run a cleanup on the image log directory to cleanup logs for
  # images that are no longer being built
  if ($image_log_periodic_cleanup) {
    cron { 'image_log_cleanup' :
      user        => $user,
      hour        => '1',
      minute      => '0',
      command     => "find ${image_log_document_root} \\( -name '*.log' -o -name '*.log.*' \\) -mtime +7 -execdir rm {} \\;",
      environment => 'PATH=/usr/bin:/bin:/usr/sbin:/sbin',
    }
  }

  if ($sudo) {
    $sudo_file_ensure = present
  }
  else {
    $sudo_file_ensure = absent
  }
  file { '/etc/sudoers.d/nodepool-sudo' :
    ensure => $sudo_file_ensure,
    source => 'puppet:///modules/nodepool/nodepool-sudo.sudo',
    owner  => 'root',
    group  => 'root',
    mode   => '0440',
  }

  class { '::nodepool::builder' :
    builder_logging_conf_template => $builder_logging_conf_template,
    environment                   => $environment,
    statsd_host                   => $statsd_host,
  }

}
