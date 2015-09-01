notice('MODULAR: detach-keystone/haproxy.pp')

$network_metadata = hiera_hash('network_metadata')
$keystone_hash    = hiera_hash('keystone', {})
# enabled by default
$use_keystone = pick($keystone_hash['enabled'], true)
$public_ssl_hash = hiera('public_ssl')
$database_vip    = hiera('database_vip')
#todo(sv): change to 'keystone' as soon as keystone as node-role was ready    
$keystones_address_map = get_node_to_ipaddr_map_by_network_role(get_nodes_hash_by_roles($network_metadata, ['primary-standalone-keystone', 'standalone-keystone']), 'keystone/api')

if ($use_keystone) {
  $server_names        = pick(hiera_array('keystone_names', undef),
                              keys($keystones_address_map))
  $ipaddresses         = pick(hiera_array('keystone_ipaddresses', undef),
                              values($keystones_address_map))
  $internal_virtual_ip = pick(hiera('service_endpoint', undef), hiera('management_vip'))

  # Don't deploy on public service endpoint if SSL enabled
  if $public_ssl_hash['services'] {
    $public_virtual_ip = $internal_virtual_ip
  } else {
    $public_virtual_ip   = pick(hiera('public_service_endpoint', undef), hiera('public_vip'))
  }

  # configure keystone ha proxy
  class { '::openstack::ha::keystone':
    internal_virtual_ip => $internal_virtual_ip,
    ipaddresses         => $ipaddresses,
    public_virtual_ip   => $public_virtual_ip,
    server_names        => $server_names,
    public_ssl          => false,
  }

  Package['socat'] -> Class['openstack::ha::keystone']

  package { 'socat':
    ensure => 'present',
  }
}

Haproxy::Service        { use_include => true }
Haproxy::Balancermember { use_include => true }

