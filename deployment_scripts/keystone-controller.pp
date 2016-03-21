notice('MODULAR: detach-keystone/keystone-controller.pp')

$network_metadata = hiera('network_metadata')
$access_hash      = hiera_hash('access',{})
$service_endpoint = hiera('service_endpoint')
$management_vip   = hiera('management_vip')
$public_vip       = hiera('public_vip')

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
$public_ssl_path = get_ssl_property($ssl_hash, $public_ssl_hash, 'keystone', 'public', 'path', [''])

$public_protocol = get_ssl_property($ssl_hash, $public_ssl_hash, 'keystone', 'public', 'protocol', 'http')
$public_address  = get_ssl_property($ssl_hash, $public_ssl_hash, 'keystone', 'public', 'hostname', [$public_vip])
$public_port     = '5000'

$internal_protocol = get_ssl_property($ssl_hash, {}, 'keystone', 'internal', 'protocol', 'http')
$internal_address  = get_ssl_property($ssl_hash, {}, 'keystone', 'internal', 'hostname', [$management_vip])
$internal_port     = '5000'

$admin_protocol = get_ssl_property($ssl_hash, {}, 'keystone', 'admin', 'protocol', 'http')
$admin_address  = get_ssl_property($ssl_hash, {}, 'keystone', 'admin', 'hostname', [$management_vip])
$admin_port     = '35357'

$public_url   = "${public_protocol}://${public_address}:${public_port}"
$admin_url    = "${admin_protocol}://${admin_address}:${admin_port}"
$internal_url = "${internal_protocol}://${internal_address}:${internal_port}"

$auth_suffix  = pick($keystone_hash['auth_suffix'], '/')
$auth_url     = "${internal_url}${auth_suffix}"

class { '::osnailyfacter::auth_file':
  admin_user      => $admin_user,
  admin_password  => $admin_password,
  admin_tenant    => $admin_tenant,
  region_name     => $region,
  auth_url        => $auth_url,
}

# Enable keystone HAProxy on controller so public VIP can be used
$server_names        = [$service_endpoint]
$ipaddresses         = [$service_endpoint]

# configure keystone ha proxy
class { '::openstack::ha::keystone':
  internal_virtual_ip => $management_vip,
  ipaddresses         => $ipaddresses,
  public_virtual_ip   => $public_vip,
  server_names        => $server_names,
  public_ssl          => $public_ssl,
  public_ssl_path     => $public_ssl_path,
}

Package['socat'] -> Class['openstack::ha::keystone']

package { 'socat':
  ensure => 'present',
}
