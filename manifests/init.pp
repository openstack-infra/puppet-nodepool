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
  $nodepool_ssh_private_key = '',
  $git_source_repo = 'https://git.openstack.org/openstack-infra/nodepool',
  $revision = 'master',
  $statsd_host = '',
  $vhost_name = $::fqdn,
  $image_log_document_root = '/var/log/nodepool/image',
  $enable_image_log_via_http = false,
  $environment = {},
  # enable sudo for nodepool user. Useful for using dib with nodepool
  $sudo = true,
  $scripts_dir = '',
  $elements_dir = '',
  $logging_conf_template = 'nodepool/nodepool.logging.conf.erb',
  $manage_nodepool_template = false,
  $cron_cleanup = '*/1 * * * *',
  $cron_check = '*/15 * * * *',
  $image_update = '14 14 * * *',
  $zmq_publishers = [],  # refer to: http://docs.openstack.org/infra/nodepool/configuration.html#zmq-publishers
  $gearman_servers = [], # refer to: http://docs.openstack.org/infra/nodepool/configuration.html#gearman-servers
  # define that as:
  # $gearman_servers = [
  #     {
  #       'host' => 'gearman_host',
  #       'port' => 4730,
  #     }
  # ],
  $labels = [], # refer to: http://docs.openstack.org/infra/nodepool/configuration.html#labels
  # define that as:
  # $labels => [
  #     {
  #       'name'              => 'label name',
  #       'image'             => 'label image',
  #       'providers'         => [ 'provider1', 'provider2', ],
  #       'optional_settings' => {
  #         'ready-script' => 'label_script.sh',
  #         'min-ready'    => 2,
  #         'subnodes'     => 1,
  #        }
  #     }
  # ]
  $providers = [],# refer to: http://docs.openstack.org/infra/nodepool/configuration.html#providers
  # define that as:
  # $providers => [
  #     {
  #       'name'              => 'provider name',
  #       'username'          => 'username',
  #       'password'          => 'password',
  #       'project-id'        => 'project-id',
  #       'auth-url'          => 'http://url_for_auth',
  #       'max-servers'       => '199',
  #       'optional_settings' => {
  #         'availability-zones' => ['az1', 'az2'],
  #         'boot-timeout'   => '60',
  #         'launch-timeout' => '3600',
  #         'region-name'  => 'region name',
  #         'service-type' => 'service type',
  #         'service-name' => 'service name',
  #         'api-timeout'  => '60',
  #         'rate'         => '0.001',
  #         'images'       => [
  #           {
  #             'name'        => 'provider_image_name',
  #             'base-image'  => 'provider_base_image',
  #             'min-ram'     => '8192',
  #             'name-filter' => 'provider_name_filter',
  #             'setup'       => 'provider_setup.sh',
  #             'username'    => 'jenkins',
  #             'private-key' => '/home/nodepool/.ssh/id_rsa',
  #           },
  #         ],
  #         'networks'           => [
  #             'net-id'    => 'net-id',
  #             'net-label' => 'net-label',
  #         ],
  #       }
  #     )
  # ]
  $targets = [],# refer to: http://docs.openstack.org/infra/nodepool/configuration.html#targets
  # define that as:
  # $targets => [
  #     {
  #       'name'         => 'target name',
  #       'optional_settings' => {
  #         'jenkins' => {
  #           'url'             => 'https://url_to_jenkins',
  #           'user'            => 'jenkins_user',
  #           'apikey'          => 'jenkins_api_key',
  #           'credentials-id'  => 'jenkins_credentials_id',
  #         }
  #       }
  #     }
  # ]
  $diskimages = [],# refer to: http://docs.openstack.org/infra/nodepool/configuration.html#diskimages
  # define that as:
  # $diskimages => [
  #     {
  #       'name'              => 'diskimage name',
  #       'optional_settings' => {
  #         'elements'     => ['element1', 'element2'],
  #         'env-vars'     => {'key1': 'value1', 'key2': 'value2'},
  #         'release'      => 'trusty',
  #       },
  #     }
  # ]

) {


  class { 'mysql::server':
    config_hash => {
      'root_password'  => $mysql_root_password,
      'default_engine' => 'InnoDB',
      'bind_address'   => '127.0.0.1',
    }
  }

  include mysql::server::account_security
  include mysql::python

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

  $packages = [
    'build-essential',
    'libffi-dev',
    'libssl-dev',
    'libgmp-dev',         # transitive dep of paramiko
    # xml2 and xslt are needed to build python lxml.
    'libxml2-dev',
    'libxslt-dev',
  ]

  package { $packages:
    ensure  => present,
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

  include diskimage_builder

  include pip
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

  if ($scripts_dir != '') {
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

  if ($elements_dir != '') {
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
    include apache

    apache::vhost { $vhost_name:
      port     => 80,
      priority => '50',
      docroot  => 'MEANINGLESS_ARGUMENT',
      template => 'nodepool/nodepool-log.vhost.erb',
    }

    if $image_log_document_root != '/var/log/nodepool' {
      file { $image_log_document_root:
        ensure   => directory,
        mode     => '0755',
        owner    => 'nodepool',
        group    => 'nodepool',
        require  => [
          User['nodepool'],
          File['/var/log/nodepool'],
        ],
      }
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

  if $manage_nodepool_template {
    file { '/etc/nodepool/nodepool.yaml':
      ensure  => present,
      owner   => 'nodepool',
      group   => 'root',
      mode    => '0400',
      content => template('nodepool/nodepool.yaml.erb'),
      require => [
        File['/etc/nodepool'],
        User['nodepool'],
      ],
    }
  }
}
