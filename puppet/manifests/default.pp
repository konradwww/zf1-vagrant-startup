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
    'git-core'
  ]:
  ensure  => 'installed',
}

exec { 'zf install':
  command => 'git clone https://github.com/konradwww/zf1.git /usr/local/share/ZendFramework',
  creates => '/usr/local/share/ZendFramework',
  require => Package['git-core'],
}

file { '/usr/local/bin/zf':
  ensure => 'link',
  target => '/usr/local/share/ZendFramework/bin/zf.sh',  
  require => Exec['zf install'],
}

exec { 'zf create project':
  command => 'zf create project /vagrant/APP_ROOT',
  creates => '/vagrant/APP_ROOT',
  require => File['/usr/local/bin/zf'],
}

file { '/vagrant/APP_ROOT/library/Zend':
  ensure => 'link',
  target => '/usr/local/share/ZendFramework/library/Zend',
  require => Exec['zf create project'],
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
  docroot       => '/vagrant/APP_ROOT/public',
  server_name   => false,
  priority      => '',
  template      => 'apache/virtualhost/vhost.conf.erb',
  env_variables => [
    'APP_ENVIRONMENT development'
  ],
}

class { 'php':
  service             => 'apache',
  service_autorestart => false,
  module_prefix       => '',
}

php::module { 'php5-cli': }
php::module { 'php5-curl': }
php::module { 'php5-intl': }
php::module { 'php5-mcrypt': }

class { 'php::devel':
  require => Class['php'],
}

class { 'php::pear':
  require => Class['php'],
}


php::pecl::module { 'APC':
  use_package => false,
}
php::pecl::module { 'memcache':
  use_package => false,
}

#$xhprofPath = '/var/www/xhprof'

#php::pecl::module { 'xhprof':
#  use_package     => false,
#  preferred_state => 'beta',
#}

if !defined(Package['git-core']) {
  package { 'git-core' : }
}

#vcsrepo { $xhprofPath:
#  ensure   => present,
#  provider => git,
#  source   => 'https://github.com/facebook/xhprof.git',
#  require  => Package['git-core']
#}

#file { "${xhprofPath}/xhprof_html":
#  ensure  => 'directory',
#  owner   => 'vagrant',
#  group   => 'vagrant',
#  mode    => '0775',
#  require => Vcsrepo[$xhprofPath]
#}

#composer::run { 'xhprof-composer-run':
#  path    => $xhprofPath,
#  require => [
#    Class['composer'],
#    File["${xhprofPath}/xhprof_html"]
#  ]
#}

#apache::vhost { 'xhprof':
#  server_name => 'xhprof',
#  docroot     => "${xhprofPath}/xhprof_html",
#  port        => 80,
#  priority    => '1',
#  require     => [
#    Php::Pecl::Module['xhprof'],
#    File["${xhprofPath}/xhprof_html"]
#  ]
#}


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

puphpet::ini { 'php':
  value   => [
    'date.timezone = "Europe/Berlin"',
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



