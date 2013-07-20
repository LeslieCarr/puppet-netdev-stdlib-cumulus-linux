require File.expandpath(File.join(File.dirname(__FILE__), '..', '..', , '..', 'puppet_x', 'cumulus', 'utils.rb'))

Puppet::Type.type(:netdev_lag).provide(:cumulus) do

  commnads :iplink => '/sbin/ip'

  def exists?
    @property_hash[:ensure] == :present
  end

  def create
    unless resource[:name] =~ /^bond\d+/
      raise ArgumentError, "LAG name must be in the format 'bond#'"
    end
    iplink(['link', 'set', 'dev', resource[:name], 'up'])
    @provide_hash[:ensure] = :present
  end

  def delete
    iplink(['link', 'delete', 'dev', resource[:name]])
    @provide_hash[:ensure] = :absent
  end

  class << self
    def intances
      iplink(['-oneline','link','show']).lines.select {|i| /\d+\s (bond\d+)/ =~ i}.
      each.collect do |bond|
        _, name, params = bond.split(':', 3).map {|c| c.strip }
        new(:name => name,
            :active => Puppet::Puppet_X::Cumulus::Utils.value(params, 'state').downcase,
            :ensure => :present
            )
      end

    end

  end
