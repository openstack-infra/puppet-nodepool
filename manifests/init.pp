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
  $environment = {},
  # enable sudo for nodepool user. Useful for using dib with nodepool
  $sudo = true,
  $scripts_dir = undef,
  $elements_dir = undef,
  $logging_conf_template = 'nodepool/nodepool.logging.conf.erb',
  # TODO(pabelanger): Unused, to be removed
  $builder_logging_conf_template = 'nodepool/nodepool-builder.logging.conf.erb',
  $jenkins_masters = [],
  # TODO(pabelanger): Unused, to be removed
  $build_workers = '1',
  # TODO(pabelanger): Unused, to be removed
  $upload_workers = '4',
  $install_mysql = true,
  $mysql_db_name = 'nodepool',
  $mysql_host = 'localhost',
  $mysql_user_name = 'nodepool',
) {

  class { '::nodepool::server': {
    mysql_root_password         => $mysql_root_password,
    mysql_password              => $mysql_password,
    nodepool_ssh_private_key    => $nodepool_ssh_private_key,
    nodepool_ssh_public_key     => $nodepool_ssh_public_key,
    git_source_repo             => $git_source_repo,
    revision                    => $revision,
    statsd_host                 => $statsd_host,
    vhost_name                  => $vhost_name,
    image_log_document_root     => $image_log_document_root,
    image_log_periodic_cleanup  => $image_log_periodic_cleanup,
    enable_image_log_via_http   => $enable_image_log_via_http
    environment                 => $environment,
    sudo                        => $sudo,
    scripts_dir                 => $scripts_dir,
    elements_dir                => $elements_dir,
    logging_conf_template       => $logging_conf_template,
    jenkins_masters             => $jenkins_masters,
    install_mysql               => $install_mysql,
    mysql_db_name               => $mysql_db_name,
    mysql_host                  => $mysql_host,
    mysql_user_name             => $mysql_user_name,
  }
}
