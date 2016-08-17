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
  $nodepool_ssh_public_key = undef,
  $git_source_repo = 'https://git.openstack.org/openstack-infra/nodepool',
  $revision = 'master',
  $statsd_host = undef,
  $vhost_name = $::fqdn,
  $image_log_document_root = '/var/log/nodepool/image',
  $image_log_periodic_cleanup = false,
  $enable_image_log_via_http = false,
  $upload_log_document_root = '/var/log/nodepool/upload',
  $upload_log_periodic_cleanup = false,
  # note : not currently supported
  $enable_upload_log_via_http = false,
  $environment = {},
  # enable sudo for nodepool user. Useful for using dib with nodepool
  $sudo = true,
  $scripts_dir = undef,
  $elements_dir = undef,
  $logging_conf_template = 'nodepool/nodepool.logging.conf.erb',
  $launcher_logging_conf_template = 'nodepool/nodepool-launcher.logging.conf.erb',
  $deleter_logging_conf_template = 'nodepool/nodepool-deleter.logging.conf.erb',
  $builder_logging_conf_template = 'nodepool/nodepool-builder.logging.conf.erb',
  $jenkins_masters = [],
  $build_workers = '1',
  $upload_workers = '4',
  $install_mysql = true,
  $mysql_db_name = 'nodepool',
  $mysql_host = 'localhost',
  $mysql_user_name = 'nodepool',
  $split_daemon = false,
) {

  if($install_mysql) {
    class { '::nodepool::mysql' :
      mysql_db_name       => $mysql_db_name,
      mysql_root_password => $mysql_root_password,
      mysql_user_host     => $mysql_host,
      mysql_user_name     => $mysql_user_name,
      mysql_password      => $mysql_password,
    }
  }

  $packages = [
    'libffi-dev',
    'libssl-dev',
    'libgmp-dev',         # transitive dep of paramiko
    # xml2 and xslt are needed to build python lxml.
    'libxml2-dev',
    'libxslt-dev',
  ]

  ensure_packages($packages, {'ensure' => 'present'})

  if ! defined(Package['build-essential']) {
    package { 'build-essential':
      ensure => present,
    }
  }

  file { '/etc/mysql/conf.d/max_connections.cnf':
    ensure  => present,
    content => "[server]\nmax_connections = 8192\n",
    mode    => '0444',
    owner   => 'root',
    group   => 'root',
  }

  user { 'nodepool':
    ensure     => present,
    home       => '/home/nodepool',
    shell      => '/bin/bash',
    gid        => 'nodepool',
    managehome => true,
    require    => Group['nodepool'],
  }

  group { 'nodepool':
    ensure => present,
  }

  vcsrepo { '/opt/nodepool':
    ensure   => latest,
    provider => git,
    revision => $revision,
    source   => $git_source_repo,
  }

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

  file { '/etc/nodepool':
    ensure => directory,
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

  # used for storage of d-i-b images in non-ephemeral partition
  file { '/opt/nodepool_dib':
    ensure  => directory,
    mode    => '0755',
    owner   => 'nodepool',
    group   => 'nodepool',
    require => User['nodepool'],
  }

  # used for storage of d-i-b cached data
  file { '/opt/dib_cache':
    ensure  => directory,
    mode    => '0755',
    owner   => 'nodepool',
    group   => 'nodepool',
    require => User['nodepool'],
  }

  # used as TMPDIR during d-i-b image builds
  file { '/opt/dib_tmp':
    ensure  => directory,
    mode    => '0755',
    owner   => 'nodepool',
    group   => 'nodepool',
    require => User['nodepool'],
  }

  file { '/var/log/nodepool':
    ensure  => directory,
    mode    => '0755',
    owner   => 'nodepool',
    group   => 'nodepool',
    require => User['nodepool'],
  }

  file { '/var/run/nodepool':
    ensure  => directory,
    mode    => '0755',
    owner   => 'nodepool',
    group   => 'nodepool',
    require => User['nodepool'],
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

  if ($split_daemon) {
    file { '/etc/default/nodepool-launcher':
      ensure  => present,
      content => template('nodepool/nodepool-launcher.default.erb'),
      mode    => '0444',
      owner   => 'root',
      group   => 'root',
    }

    file { '/etc/default/nodepool-deleter':
      ensure  => present,
      content => template('nodepool/nodepool-deleter.default.erb'),
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

    file { '/etc/nodepool/deleter-logging.conf':
      ensure  => present,
      mode    => '0444',
      owner   => 'root',
      group   => 'root',
      content => template($deleter_logging_conf_template),
    }

    file { '/etc/init.d/nodepool-launcher':
      ensure => present,
      mode   => '0555',
      owner  => 'root',
      group  => 'root',
      source => 'puppet:///modules/nodepool/nodepool-launcher.init',
    }

    service { 'nodepool-launcher':
      name       => 'nodepool-launcher',
      enable     => true,
      hasrestart => true,
      require    => File['/etc/init.d/nodepool-launcher'],
    }

    file { '/etc/init.d/nodepool-deleter':
      ensure => present,
      mode   => '0555',
      owner  => 'root',
      group  => 'root',
      source => 'puppet:///modules/nodepool/nodepool-deleter.init',
    }

    service { 'nodepool-deleter':
      name       => 'nodepool-deleter',
      enable     => true,
      hasrestart => true,
      require    => File['/etc/init.d/nodepool-deleter'],
    }
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

  if $image_log_document_root == $upload_log_document_root {
    # It makes no sense to ask to not export build or upload logs, but
    # then have them log to the same directory that will be exported.
    if (($enable_image_log_via_http and !$enable_upload_log_via_http) or
        ($enable_upload_log_via_http and !$enable_image_log_via_http)
    ) {
        fail('Unexported logs in same directory as exported logs!')
    }
  }

  # we only need to create the upload log dir if it is separate to the
  # image log.
  $separate_upload_log_dir =
    $image_log_document_root != $upload_log_document_root

  if $enable_image_log_via_http == true or
    $enable_upload_log_via_http == true {
    # Setup apache for log access
    include ::httpd

    ::httpd::vhost { $vhost_name:
      port     => 80,
      priority => '50',
      docroot  => 'MEANINGLESS_ARGUMENT',
      template => 'nodepool/nodepool-log.vhost.erb',
    }
    if ! defined(Httpd::Mod['rewrite']) {
      httpd::mod { 'rewrite': ensure => present }
    }
    if ! defined(Httpd::Mod['proxy']) {
      httpd::mod { 'proxy': ensure => present }
    }
    if ! defined(Httpd::Mod['proxy_http']) {
      httpd::mod { 'proxy_http': ensure => present }
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

  # we only need this if it is different to the image_log
  if $separate_upload_log_dir
  {
    file { $upload_log_document_root:
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

  # run a cleanup on the image log directory to cleanup logs for
  # images that are no longer being built
  if $image_log_periodic_cleanup == true {
    cron { 'image_log_cleanup':
      user        => 'nodepool',
      hour        => '1',
      minute      => '0',
      command     => "find ${image_log_document_root} \\( -name '*.log' -o -name '*.log.*' \\) -mtime +7 -execdir rm {} \\;",
      environment => 'PATH=/usr/bin:/bin:/usr/sbin:/sbin',
    }
  }

  # run a cleanup on the upload log directory to cleanup logs for
  # providers that are no long uploading
  if $upload_log_periodic_cleanup == true {
    cron { 'upload_log_cleanup':
      user        => 'nodepool',
      hour        => '1',
      minute      => '0',
      command     => "find ${upload_log_document_root} \\( -name '*.log' -o -name '*.log.*' \\) -mtime +7 -execdir rm {} \\;",
      environment => 'PATH=/usr/bin:/bin:/usr/sbin:/sbin',
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

  class { '::nodepool::builder':
    statsd_host                   => $statsd_host,
    environment                   => $environment,
    builder_logging_conf_template => $builder_logging_conf_template,
    build_workers                 => $build_workers,
    upload_workers                => $upload_workers,
  }
}
