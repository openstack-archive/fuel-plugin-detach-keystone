notice('MODULAR: detach-keystone/keystone-controller.pp')

$network_metadata = hiera('network_metadata')
$access_hash      = hiera_hash('access',{})
$service_endpoint = hiera('service_endpoint')

$admin_tenant     = $access_hash['tenant']
$admin_email      = $access_hash['email']
$admin_user       = $access_hash['user']
$admin_password   = $access_hash['password']
$region           = hiera('region', 'RegionOne')

$keystone_hash    = hiera_hash('keystone', {})
# enabled by default
$public_ssl_hash = hiera('public_ssl')
$ssl_hash = hiera_hash('use_ssl', {})

$public_ssl = get_ssl_property($ssl_hash, $public_ssl_hash, 'keystone', 'public', 'usage', false)
$public_ssl_path = get_ssl_property($ssl_hash, $public_ssl_hash, 'services', 'public', 'path', [''])

#todo(sv): change to 'keystone' as soon as keystone as node-role was ready
$keystones_address_map = get_node_to_ipaddr_map_by_network_role(get_nodes_hash_by_roles($network_metadata, ['primary-standalone-keystone', 'standalone-keystone']), 'keystone/api')

$murano_settings_hash = hiera('murano_settings', {})
if has_key($murano_settings_hash, 'murano_repo_url') {
  $murano_repo_url = $murano_settings_hash['murano_repo_url']
} else {
  $murano_repo_url = 'http://storage.apps.openstack.org'
}

class { 'openstack::auth_file':
  admin_user      => $admin_user,
  admin_password  => $admin_password,
  admin_tenant    => $admin_tenant,
  region_name     => $region,
  controller_node => $service_endpoint,
  murano_repo_url => $murano_repo_url,
}

# Enable keystone HAProxy on controller so public VIP can be used
$server_names        = pick(hiera_array('keystone_names', undef),
                            keys($keystones_address_map))
$ipaddresses         = pick(hiera_array('keystone_ipaddresses', undef),
                            values($keystones_address_map))
$public_virtual_ip   = hiera('public_vip')
$internal_virtual_ip = hiera('management_vip')
# configure keystone ha proxy
class { '::openstack::ha::keystone':
  internal_virtual_ip => $internal_virtual_ip,
  ipaddresses         => $ipaddresses,
  public_virtual_ip   => $public_virtual_ip,
  server_names        => $server_names,
  public_ssl          => $public_ssl,
  public_ssl_path     => $public_ssl_path,
}

Package['socat'] -> Class['openstack::ha::keystone']

package { 'socat':
  ensure => 'present',
}
