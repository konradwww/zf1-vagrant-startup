group { 'puppet': ensure => present }
Exec { path => [ '/bin/', '/sbin/', '/usr/bin/', '/usr/sbin/', '/usr/local/bin' ] }
File { owner => 0, group => 0, mode => 0644 }

class {'apt':
  always_apt_update => true,
}

Class['::apt::update'] -> Package <|
    title != 'python-software-properties'
and title != 'software-properties-common'
|>

    
class { 'puphpet::dotfiles': }

package { [
    'build-essential',
    'vim',
    'curl',
    'git-core',
    'libpcre3-dev',
    'graphviz',
    'phppgadmin',
  ]:
  ensure  => 'installed',
}

#Zend Framework clone
$zendFrameworkPath = '/usr/local/share/ZendFramework'
vcsrepo { $zendFrameworkPath:
  ensure   => present,
  provider => git,
  source   => 'https://github.com/konradwww/zf1.git',
  revision => 'release-1.12.3',
  require  => Package['git-core'],
}

file { '/usr/local/bin/zf':
  ensure => 'link',
  target => '/usr/local/share/ZendFramework/bin/zf.sh',  
  require => Vcsrepo[$zendFrameworkPath],
}

exec { 'zf create project':
  command => 'zf create project /vagrant/APP_ROOT',
  creates => '/vagrant/APP_ROOT/library',
  require => File['/usr/local/bin/zf'],
}

file { '/vagrant/APP_ROOT/library/Zend':
  ensure => 'link',
  target => '/usr/local/share/ZendFramework/library/Zend',
  require => Exec['zf create project'],
}  

file {'/vagrant/APP_ROOT/system':
  ensure  => 'directory',
  require => Exec['zf create project'],
}

file { '/vagrant/APP_ROOT/system/phpinfo.php':
  ensure  => present,
  content => '<?php phpinfo();',
  require => File['/vagrant/APP_ROOT/system'],
}

file { '/vagrant/logs':
  ensure => 'directory',
}

class { 'apache':
  log_dir => '/vagrant/logs',
  require => File['/vagrant/logs'],
}



apache::dotconf { 'custom':
  content => 'EnableSendfile Off',
}

apache::module { 'rewrite': }

apache::vhost { 'default':
  docroot           => '/vagrant/APP_ROOT/public',
  server_name       => 'localhost',
  priority          => '',
  template          => 'apache/virtualhost/vhost.conf.erb',
  env_variables     => [
    'APP_ENVIRONMENT development',
  ],
}

class { 'php':
  service             => 'apache',
  service_autorestart => false,
  module_prefix       => '',
}

php::module { 'php5-mysql': }
php::module { 'php5-pgsql': }
php::module { 'php5-cli': }
php::module { 'php5-curl': }
php::module { 'php5-intl': }
php::module { 'php5-mcrypt': }
php::module { 'php5-gd': }


php::pecl::module { 'apc':
  version         => '3.1.13',
  use_package     => false,
  preferred_state => 'beta',
  before          => File['/vagrant/APP_ROOT/system/apc.php'],
  notify          => Service['apache'],  
  require         => [ Package['libpcre3-dev'] ], 
}

file { '/vagrant/APP_ROOT/system/apc.php':
  ensure  => 'link',
  target  => '/usr/share/php/apc.php',
  require => [ File['/vagrant/APP_ROOT/system'] ],
}

class { 'php::devel':
  require => Class['php'],
}

class { 'php::pear':
  require => Class['php'],
}

php::pear::module { 'PHPUnit':
  repository  => 'pear.phpunit.de',
  use_package => 'no',
}

$xhprofPath = '/vagrant/APP_ROOT/system/xhprof'

php::pecl::module { 'xhprof':
  use_package     => false,
  preferred_state => 'beta',
}

if !defined(Package['git-core']) {
  package { 'git-core' : }
}

vcsrepo { $xhprofPath:
  ensure   => present,
  provider => git,
  source   => 'https://github.com/facebook/xhprof.git',
  require  => Package['git-core']
}

file { "${xhprofPath}/xhprof_html":
  ensure  => 'directory',
  owner   => 'vagrant',
  group   => 'vagrant',
  mode    => '0775',
  require => Vcsrepo[$xhprofPath]
}

composer::run { 'xhprof-composer-run':
  path    => $xhprofPath,
  require => [
    Class['composer'],
    File["${xhprofPath}/xhprof_html"]
  ]
}

apache::vhost { 'xhprof':
  server_name => 'xhprof',
  docroot     => "${xhprofPath}/xhprof_html",
  port        => 80,
  priority    => '1',
  require     => [
    Php::Pecl::Module['xhprof'],
    File["${xhprofPath}/xhprof_html"]
  ]
}


class { 'xdebug':
  service => 'apache',
}

class { 'composer':
  require => Package['php5', 'curl'],
}

puphpet::ini { 'xdebug':
  value   => [
    'xdebug.default_enable = 1',
    'xdebug.remote_autostart = 0',
    'xdebug.remote_connect_back = 1',
    'xdebug.remote_enable = 1',
    'xdebug.remote_handler = "dbgp"',
    'xdebug.remote_port = 9000'
  ],
  ini     => '/etc/php5/conf.d/zzz_xdebug.ini',
  notify  => Service['apache'],
  require => Class['php'],
}

puphpet::ini { 'xhprof':
  value   => [
    'extension=xhprof.so',
    'xhprof.output_dir = "/tmp"'
  ],
  ini     => '/etc/php5/conf.d/zzz_xhprof.ini',
  notify  => Service['apache'],
  require => Class['php'],
}
puphpet::ini { 'php':
  value   => [
    'date.timezone = "Europe/Berlin"',
    'extension=apc.so',
  ],
  ini     => '/etc/php5/conf.d/zzz_php.ini',
  notify  => Service['apache'],
  require => Class['php'],
}

puphpet::ini { 'custom':
  value   => [
    'display_errors = On',
    'error_reporting = -1',
    'error_log = "/vagrant/logs/php_error.log"',
  ],
  ini     => '/etc/php5/conf.d/zzz_custom.ini',
  notify  => Service['apache'],
  require => Class['php'],
}

#mySQL
class { 'mysql::server':
  config_hash   => { 'root_password' => 'changeThisPassword' }
}

mysql::db { 'db_development':
  grant    => [
    'ALL'
  ],
  user     => 'user1',
  password => 'changeThisPassword',
  host     => 'localhost',
  charset  => 'utf8',
  require  => Class['mysql::server'],
}

class { 'phpmyadmin':
  require => [Class['mysql::server'], Class['mysql::config'], Class['php']],
}

file { '/vagrant/APP_ROOT/system/phpmyadmin':
  ensure  => 'link',
  target  => '/usr/share/phpmyadmin',
  require => Class['phpmyadmin'],
}


#postgreSQL
class { 'postgresql':
  charset => 'UTF8',
  locale  => 'en_US.UTF-8',
}->
class { 'postgresql::server':
  config_hash => {
    postgres_password => 'changeThisPassword',
  },
}

postgresql::db { 'db_development':
  user     => 'user1',
  password => 'changeThisPassword',
  grant    => 'ALL',
}

file { '/vagrant/APP_ROOT/system/phppgadmin':
  ensure  => 'link',
  target  => '/usr/share/phppgadmin',
  require => Package['phppgadmin'],
}
