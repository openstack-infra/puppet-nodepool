# OpenStack Nodepool Module

## Overview

Configures Nodepool node.

```puppet
class { 'nodepool':
  'mysql_root_password' => 'xxx',
  'mysql_password'      => 'xxx',
  'jenkins_masters'     => [
    {
      'name'        => 'jenkins_name'
      'user'        => 'jenkins_user',
      'apikey'      => 'jenkins_pass',
      'credentials' => 'jenkins_credentials_id',
      'url'         => 'jenkins_url',
      'test_job'    => 'optional_jenkins_test_job'
    }
  ]
}
```

  
