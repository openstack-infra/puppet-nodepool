# == Class: nodepool::mysql
#
class nodepool::mysql (
  $mysql_bind_address     = '127.0.0.1',
  $mysql_default_engine   = 'InnoDB',
  $mysql_db_name          = 'nodepool',
  $mysql_max_connections  = 8192,
  $mysql_root_password    = $nodepool::mysql_root_password,
  $mysql_user_host_access = 'localhost',
  $mysql_user_name        = 'nodepool',
  $mysql_user_password    = $nodepool::mysql_password,
) inherits nodepool {

  $mysql_data = load_module_metadata('mysql', true)
  if ($mysql_data == {}) {
    class { '::mysql::server' :
      config_hash => {
        'bind_address'    => $mysql_bind_address,
        'default_engine'  => $mysql_default_engine,
        'max_connections' => $mysql_max_connections,
        'root_password'   => $mysql_root_password,
      }
    }
  } else { # If it has metadata.json, assume it's new enough to use this interface
    class { '::mysql::server' :
      override_options => {
        'mysqld' => {
          'default-storage-engine' => $mysql_default_engine,
          'max_connections'        => $mysql_max_connections,
        }
      },
      root_password    => $mysql_root_password,
    }
  }

  include ::mysql::server::account_security

  mysql::db { $mysql_db_name :
    user     => $mysql_user_name,
    password => $mysql_user_password,
    host     => $mysql_user_host_access,
    grant    => ['all'],
    charset  => 'utf8',
    require  => [
      Class['mysql::server'],
      Class['mysql::server::account_security'],
    ],
  }

}
