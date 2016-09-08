# == Class: neutron::agents::ml2::networking-vpp
#
# Setups networking-vpp Neutron agent for ML2 plugin.
#
# === Parameters
#
# [*package_ensure*]
#   (optional) Package ensure state.
#   Defaults to 'present'.
#
# [*enabled*]
#   (required) Whether or not to enable the agent.
#   Defaults to true.
#
# [*manage_service*]
#   (optional) Whether to start/stop the service
#   Defaults to true
#
# [*physnets*]
#   List of <physical_network>:<physical_interface>
#   tuples mapping physical network names to agent's node-specific physical
#   network interfaces. Defaults to empty list.
#
# [*flat_network_if*]
#   VPP interface used for flat network
#   Defaults to ''.
#
class neutron::agents::ml2::networking-vpp (
  $package_ensure   = 'present',
  $enabled          = true,
  $manage_service   = true,
  $physnets         = '',
  $flat_network_if  = '',
) {

  include ::neutron::params

  if $manage_service {
    if $enabled {
      $service_ensure = 'running'
    } else {
      $service_ensure = 'stopped'
    }
  }

  neutron_plugin_ml2 {
    'ml2_vpp/physnets': value => $physnets;
    'ml2_vpp/flat_network_if': value => $flat_network_if;
  }->
  service { 'networking-vpp-agent':
    ensure    => $service_ensure,
    name      => 'networking-vpp-agent',
    enable    => $enabled,
    tag       => 'neutron-service',
  }
}