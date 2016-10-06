#
# Install the networking-vpp ML2 mechanism driver and generate config file
# from parameters in the other classes.
#
# === Parameters
#
# [*package_ensure*]
# (optional) The intended state of the networking-vpp
# package, i.e. any of the possible values of the 'ensure'
# property for a package resource type.
# Defaults to 'present'
#
# [*etcd_host*]
# (required) etcd server host name or IP.
# Defaults to '127.0.0.1'
#
# [*etcd_port*]
# (optional) etcd server listening port.
# Defaults to 4001.
#
# [*etcd_user*]
# (optional) User name for etcd authentication
# Defaults to ''.
#
# [*etcd_pass*]
# (optional) Password for etcd authentication
# Defaults to ''.
#
class neutron::plugins::ml2::networking-vpp (
  $package_ensure  = 'present',
  $etcd_host       = '127.0.0.1',
  $etcd_port       = 4001,
  $etcd_user       = '',
  $etcd_pass       = '',
) {
  require ::neutron::plugins::ml2

  ensure_resource('package', 'networking-vpp',
    {
      ensure => $package_ensure,
      tag    => 'openstack',
    }
  )

  neutron_plugin_ml2 {
    'ml2_vpp/etcd_host': value => $etcd_host;
    'ml2_vpp/etcd_port': value => $etcd_port;
    'ml2_vpp/etcd_user': value => $etcd_user;
    'ml2_vpp/etcd_pass': value => $etcd_pass;
  }
}
