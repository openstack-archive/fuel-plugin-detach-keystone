notice('MODULAR: detach-keystone/hiera-override.pp')

$detach_keystone_plugin = hiera('detach-keystone', undef)
$hiera_dir              = '/etc/hiera/plugins'
$plugin_name            = 'detach-keystone'
$plugin_yaml            = "${plugin_name}.yaml"

if $detach_keystone_plugin {
  $network_metadata = hiera_hash('network_metadata')
  if ! $network_metadata['vips']['service_endpoint'] {
    fail('Keystone service endpoint VIP is not defined')
  }
  if ! $network_metadata['vips']['public_service_endpoint'] {
    fail('Keystone service endpoint public VIP is not defined')
  }

  $settings_hash       = parseyaml($detach_keystone_plugin['yaml_additional_config'], {})

  $keystone_vip        = pick($settings_hash['remote_keystone'],
                              $network_metadata['vips']['service_endpoint']['ipaddr'])

  $public_keystone_vip = pick($settings_hash['remote_keystone'],
                              $network_metadata['vips']['public_service_endpoint']['ipaddr'])

  $nodes_hash          = $network_metadata['nodes']
  $keystone_roles       =  ['primary-standalone-keystone',
    'standalone-keystone']
  $keystone_nodes       = get_nodes_hash_by_roles($network_metadata,
    $keystone_roles)
  $keystone_address_map = get_node_to_ipaddr_map_by_network_role($keystone_nodes, 'keystone/api')
  $keystone_nodes_ips   = ipsort(values($keystone_address_map))
  $keystone_nodes_names = keys($keystone_address_map)

  $roles = join(hiera('roles'), ',')
  case $roles {
    /primary-standalone-keystone/: {
      $primary_keystone = true
      $primary_controller = true
    }
    /^primary/: {
      $primary_keystone = false
      $primary_controller = true
    }
    default: {
      $primary_database = false
      $primary_controller = false
    }
  }
  case $roles {
    /keystone/: {
      $corosync_roles      = $keystone_roles
      $corosync_nodes      = $keystone_nodes
      $colocate_haproxy    = 'false'
      $memcache_roles      = $keystone_roles
      $memcache_nodes      = $keystone_nodes
      $memcached_addresses = ipsort(values(get_node_to_ipaddr_map_by_network_role($keystone_nodes,'mgmt/memcache')))
      $deploy_vrouter      = 'false'
      $keystone_enabled    = 'true'
    }
    /controller/: {
      $deploy_vrouter   = 'true'
      $keystone_enabled = 'false'
    }
    default: {
      $keystone_enabled = 'false'
    }
  }

  $calculated_content = inline_template('
primary_keystone: <%= @primary_keystone %>
service_endpoint: <%= @keystone_vip %>
public_service_endpoint: <%= @public_keystone_vip %>
keystone_vip: <%= @keystone_vip %>
public_keystone_vip: <%= @public_keystone_vip %>
keystone:
  enabled: <%= @keystone_enabled %>
keystone_ipaddresses:
<% if @keystone_nodes_ips -%>
<%
@keystone_nodes_ips.each do |keystone_ip|
%>  - <%= keystone_ip %>
<% end -%>
<% end -%>
<% if @keystone_nodes_names -%>
keystone_names:
<%
@keystone_nodes_names.each do |keystone_name|
%>  - <%= keystone_name %>
<% end -%>
<% end -%>
primary_controller: <%= @primary_controller %>
<% if @corosync_roles -%>
corosync_roles:
<%
@corosync_roles.each do |crole|
%>  - <%= crole %>
<% end -%>
<% end -%>
<% if @colocate_haproxy -%>
colocate_haproxy: <%= @colocate_haproxy %>
<% end -%>
<% if @memcache_roles -%>
memcache_roles:
<%
@memcache_roles.each do |mrole|
%>  - <%= mrole %>
<% end -%>
<% end -%>
<% if @memcached_addresses -%>
memcached_addresses:
<%
@memcached_addresses.each do |maddr|
%>  - <%= maddr %>
<% end -%>
<% end -%>
deploy_vrouter: <%= @deploy_vrouter %>
')

  file { "${hiera_dir}/${plugin_yaml}":
    ensure  => file,
    content => "${detach_keystone_plugin['yaml_additional_config']}\n${calculated_content}\n",
  }

  package { 'ruby-deep-merge':
    ensure  => 'installed',
  }

  #FIXME(mattymo): https://bugs.launchpad.net/fuel/+bug/1479317
  package { 'python-openstackclient':
    ensure => 'installed',
  }
}
