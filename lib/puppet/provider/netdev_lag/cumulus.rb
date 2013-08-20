require File.join(File.dirname(__FILE__), '..', 'cumulus', 'network_interfaces.rb')
require File.join(File.dirname(__FILE__), '..', '..', '..', 'puppet_x', 'cumulus', 'utils.rb')

Puppet::Type.type(:netdev_lag).provide(:cumulus) do

  commands :iplink => '/sbin/ip'

  mk_resource_methods

  def initialize(value={})
    super(value)
    @property_flush = {}
    NetworkInterfaces.parse
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  def create
    unless resource[:name] =~ /^bond\d+/
      raise ArgumentError, "LAG name must be in the format 'bond#'"
    end
    iplink(['link', 'set', 'dev', resource[:name], 'up'])
    NetworkInterfaces[resource[:name]].onboot = true
    NetworkInterfaces[resource[:name]].family = 'inet'
    NetworkInterfaces[resource[:name]].method = 'manual'
    NetworkInterfaces[resource[:name]].options['bond-mode'] = ['802.3ad']
    NetworkInterfaces[resource[:name]].options['bond-miimon'] = [100]
    NetworkInterfaces[resource[:name]].options['bond-use-carrier'] = [1]
    NetworkInterfaces[resource[:name]].options['bond-lacp-rate'] = [1]
    NetworkInterfaces[resource[:name]].options['bond-min-link'] = [1]
    NetworkInterfaces[resource[:name]].options['bond-xmit_hash_policy'] = ['layer3+4']
    @provide_hash[:ensure] = :present
  end

  def delete
    iplink(['link', 'delete', 'dev', resource[:name]])
    @provide_hash[:ensure] = :absent
  end

  def links=(value)
    @property_flush[:links] = value
  end

  def flush
    NetworkInterfaces[resource[:name]].options['bond-slaves'] =
      @property_flush[:links] if @property_flush[:links]

    NetworkInterfaces.flush
  end

  def self.instances
    iplink(['-oneline','link','show']).lines.select {|i| /\d+\s (bond\d+)/ =~ i}.
      each.collect do |bond|
        _, name, params = bond.split(':', 3).map {|c| c.strip }
        new(:name => name,
            :active => Puppet_X::Cumulus::Utils.value(params, 'state').downcase,
            :ensure => :present
            )
      end
  end

  def self.prefetch(resources)
    lags = instances
    resources.each do |name, params|
      if provider = lags.find { |lag| lag.name == params[:name] }
        resources[name].provider = provider
      end
    end
  end

end
