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
  $build_workers                 = '1',
  $builder_logging_conf_template = 'nodepool/nodepool-builder.logging.conf.erb',
  $environment                   = {},
  $image_log_document_root       = '/var/log/nodepool/image',
  $statsd_host                   = undef,
  $upload_workers                = '4',
) {

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

}
