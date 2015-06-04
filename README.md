# OpenStack Nodepool Module

## Overview

Configures Nodepool node.

```puppet
class { '::nodepool':
  mysql_root_password      => 'xxx',
  mysql_password           => 'xxx',
  nodepool_ssh_private_key => 'optional_key_content',
  environment => {
    optional_setting_1 => 'optional_value_1',
    optional_setting_2 => 'optional_value_2',
  },
  jenkins_masters     => [
    {
      name        => 'jenkins_name'
      user        => 'jenkins_user',
      apikey      => 'jenkins_pass',
      credentials => 'jenkins_credentials_id',
      url         => 'jenkins_url',
    }
  ]
}
```
