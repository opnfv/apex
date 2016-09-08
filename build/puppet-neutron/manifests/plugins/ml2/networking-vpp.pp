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
# [*agents*]
# Networking-vpp agents's addresses
# Defaults to $::os_service_default
#
class neutron::plugins::ml2::networking-vpp (
  $package_ensure  = 'present',
  $agents          = $::os_service_default,
) {
  require ::neutron::plugins::ml2

  ensure_resource('package', 'networking-vpp',
    {
      ensure => $package_ensure,
      tag    => 'openstack',
    }
  )

  neutron_plugin_ml2 {
    'ml2_vpp/agents': value => $agents;
  }
}
