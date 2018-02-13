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

# == Class: nodepool::builder
#
class nodepool::builder(
  $statsd_host = undef,
  $nodepool_ssh_public_key = undef,
  # If true, export build logs from $build_log_document_root via apache
  $enable_build_log_via_http = true,
  $build_log_document_root = '/var/log/nodepool/builds',
  $vhost_name = $::fqdn,
  $builder_logging_conf_template = 'nodepool/nodepool-builder.logging.conf.erb',
  $environment = {},
  $build_workers = '1',
  $upload_workers = '4',
  $zuulv3 = false,
) {

  include ::diskimage_builder

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

  file { '/etc/init.d/nodepool-builder':
    ensure => present,
    mode   => '0555',
    owner  => 'root',
    group  => 'root',
    source => 'puppet:///modules/nodepool/nodepool-builder.init',
  }

  file { '/etc/default/nodepool-builder':
    ensure  => present,
    content => template('nodepool/nodepool-builder.default.erb'),
    mode    => '0444',
    owner   => 'root',
    group   => 'root',
  }

  file { '/etc/nodepool/builder-logging.conf':
    ensure  => present,
    mode    => '0444',
    owner   => 'root',
    group   => 'root',
    content => template($builder_logging_conf_template),
  }

  if ($::operatingsystem == 'Ubuntu') and ($::operatingsystemrelease >= '16.04') {
    # This is a hack to make sure that systemd is aware of the new service
    # before we attempt to start it.
    exec { 'nodepool-builder-systemd-daemon-reload':
      command     => '/bin/systemctl daemon-reload',
      before      => Service['nodepool-builder'],
      subscribe   => File['/etc/init.d/nodepool-builder'],
      refreshonly => true,
    }
  }

  service { 'nodepool-builder':
    name       => 'nodepool-builder',
    enable     => true,
    hasrestart => true,
    require    => [
      File['/etc/init.d/nodepool-builder'],
      File['/etc/default/nodepool-builder'],
      File['/etc/nodepool/builder-logging.conf'],
    ],
  }

  if $enable_build_log_via_http == true {
    include ::httpd

    ::httpd::vhost { $vhost_name:
      port     => 80,
      priority => '50',
      docroot  => 'MEANINGLESS_ARGUMENT',
      template => 'nodepool/nodepool-builder.vhost.erb',
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

  file { $build_log_document_root:
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
