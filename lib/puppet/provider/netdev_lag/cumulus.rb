$LOAD_PATH.unshift(File.join(File.dirname(__FILE__),"..","..",".."))
require 'puppet/provider/cumulus/cumulus_parent'
require 'puppet/provider/cumulus/network_interfaces'

Puppet::Type.type(:netdev_lag).provide(:cumulus, :parent => Puppet::Provider::Cumulus) do

  commands :iplink => '/sbin/ip', :ethtool  => '/sbin/ethtool'

  mk_resource_methods

  def create
    unless resource[:name] =~ /^bond\d+/
      raise ArgumentError, "LAG name must be in the format 'bond#'"
    end
    iplink(['link', 'set', 'dev', resource[:name], 'up'])
    # NetworkInterfaces[resource[:name]].onboot = true
    # NetworkInterfaces[resource[:name]].family = 'inet'
    # NetworkInterfaces[resource[:name]].method = 'manual'
    # NetworkInterfaces[resource[:name]].options['bond-mode'] = ['802.3ad']
    # NetworkInterfaces[resource[:name]].options['bond-miimon'] = [100]
    # NetworkInterfaces[resource[:name]].options['bond-use-carrier'] = [1]
    # NetworkInterfaces[resource[:name]].options['bond-lacp-rate'] = [1]
    # NetworkInterfaces[resource[:name]].options['bond-min-link'] = [1]
    # NetworkInterfaces[resource[:name]].options['bond-xmit_hash_policy'] = ['layer3+4']
  end

  def delete
    iplink(['link', 'delete', 'dev', resource[:name]])
  end

  def links=(value)
    @property_flush[:links] = value
  end

  def self.instances
    lags.collect { |i| new(i) }
  end

end
