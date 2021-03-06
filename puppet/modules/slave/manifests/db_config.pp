define slave::db_config(
  $ensure = 'present',
  $jenkins_home = '/home/jenkins',
  $jenkins_user = "jenkins",
  $jenkins_group = "jenkins"
) {
  file { "$jenkins_home/$title.db.yaml":
    ensure => 'present',
    source => "puppet:///modules/slave/db/$title",
    owner => $jenkins_user,
    group => $jenkins_group
  }
}
