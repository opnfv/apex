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
# [*etcd_host*]
#   etcd server host name/ip
#   Defaults to 127.0.0.1.
#
# [*etcd_port*]
#   etcd server listening port.
#   Defaults to 4001.
#
class neutron::agents::ml2::networking-vpp (
  $package_ensure   = 'present',
  $enabled          = true,
  $manage_service   = true,
  $physnets         = '',
  $etcd_host        = '127.0.0.1',
  $etcd_port        = 4001,
) {

  include ::neutron::params

  if $manage_service {
    if $enabled {
      $service_ensure = 'running'
    } else {
      $service_ensure = 'stopped'
    }
  }

  neutron_agent_vpp {
    'ml2_vpp/physnets': value => $physnets;
    'ml2_vpp/etcd_host': value => $etcd_host;
    'ml2_vpp/etcd_port': value => $etcd_port;
    'DEFAULT/host': value => $::fqdn;
  }->
  service { 'networking-vpp-agent':
    ensure    => $service_ensure,
    name      => 'networking-vpp-agent',
    enable    => $enabled,
    tag       => 'neutron-service',
  }
}