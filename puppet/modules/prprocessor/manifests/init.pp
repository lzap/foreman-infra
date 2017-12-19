# Class to set up the PR processor
#
class prprocessor (
  String $github_oauth_token,
  String $github_secret_token,
  String $redmine_api_key,
  String $jenkins_token,
  String $username               = 'prprocessor',
  String $servername             = 'prprocessor.theforeman.org',
  Stdlib::Httpsurl $repo_url     = 'https://github.com/theforeman/prprocessor.git',
  Stdlib::Absolutepath $app_root = '/usr/share/prprocessor',
  Boolean $https                 = false,
) {
  # TODO: cron @weekly scripts/close_inactive.rb

  user { $username:
    ensure => 'present',
    shell  => '/bin/false',
    home   => $app_root,
  }

  # Needed for bundle install
  $packages = [
    'gcc',
    'make',
    'ruby-devel',
    'rubygem-bundler',
  ]

  ensure_packages($packages)

  # App install

  vcsrepo { $app_root:
    ensure   => present,
    provider => 'git',
    source   => $repo_url,
    user     => $username,
    notify   => Exec['install prprocessor'],
  }

  exec { 'install prprocessor':
    command => 'bundle install',
    user    => $username,
    cwd     => $app_root,
    path    => $::path,
    unless  => 'bundle check',
    require => Package[$packages],
  }

  # Apache / Passenger

  include ::web::base

  $docroot = '/var/www/html'
  $env = [
    "GITHUB_OAUTH_TOKEN ${github_oauth_token}",
    "GITHUB_SECRET_TOKEN ${github_secret_token}",
    "REDMINE_API_KEY ${redmine_api_key}",
    "JENKINS_TOKEN ${jenkins_token}",
  ]

  letsencrypt::certonly { $servername:
    plugin        => 'webroot',
    manage_cron   => false,
    domains       => [$servername],
    webroot_paths => [$docroot],
  }

  apache::vhost { $servername:
    add_default_charset => 'UTF-8',
    docroot             => $docroot,
    manage_docroot      => false,
    port                => 80,
    options             => [],
    passenger_app_root  => $app_root,
    servername          => $servername,
    setenv              => $env,
    require             => Exec['install prprocessor'],
  }

  if $https {
    apache::vhost { "${servername}-https":
      add_default_charset => 'UTF-8',
      docroot             => $docroot,
      manage_docroot      => false,
      port                => 443,
      options             => [],
      passenger_app_root  => $app_root,
      servername          => $servername,
      setenv              => $env,
      ssl                 => true,
      ssl_cert            => "/etc/letsencrypt/live/${servername}/fullchain.pem",
      ssl_chain           => "/etc/letsencrypt/live/${servername}/chain.pem",
      ssl_key             => "/etc/letsencrypt/live/${servername}/privkey.pem",
      require             => [Letsencrypt::Certonly[$servername], Exec['install prprocessor']],
    }
  }
}