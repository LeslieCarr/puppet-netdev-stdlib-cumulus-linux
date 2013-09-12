require 'set'
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__),"..","..",".."))
require 'puppet/provider/cumulus/cumulus_parent'
require 'puppet/provider/cumulus/network_interfaces'

Puppet::Type.type(:netdev_lag).provide(:cumulus, :parent => Puppet::Provider::Cumulus) do

  # commands :ip => '/sbin/ip'

  NET_CLASS = '/sys/class/net'
  BONDING_MASTERS = '/sys/class/net/bonding_masters'

  mk_resource_methods

  # def active=(value)
  # @property_flush[:active] = value
  # end

  def minimum_links=(value)
    @property_flush[:minimum_links] = value
  end

  def links=(value)
    @property_flush[:links] = value
  end

  def create
    bonding_masters_append "+#{resource[:name]}"
  end

  def destroy
    bonding_masters_append "-#{resource[:name]}"
  end

  def apply
    if @property_flush[:links]
      existing_slaves = Set.new(get_bond_slaves resource[:name])
      should_slaves = Set.new(@property_flush[:links])
      remove_slaves = existing_slaves - should_slaves
      remove_slaves.each {|i| bond_slave_modify resource[:name], "-#{i}"}
      should_slaves.each {|i| bond_slave_modify resource[:name], "+#{i}"}
    end
    # iplink(['link', 'set', resource[:name], to_updown(@property_flush[:active])]) if @property_flush[:active]
  end

  def persist
    if @property_flush
      network_interfaces = NetworkInterfaces.parse
      bond = network_interfaces[resource[:name]]
      # bond.onboot = @property_flush[:active] if @property_flush[:active]
      bond.options['bond-slaves'] = [@property_flush[:links].join ' '] if @property_flush[:links]
      bond.options['bond-min-links'] = [@property_flush[:minimum_links]] if @property_flush[:minimum_links]
      network_interfaces.flush
    end
  end


  def self.instances
    lags.collect { |i| new(i) }
  end

  private

  def to_updown value
    if value and (value == true)
      'up'
    else
      'down'
    end
  end

  def bonding_masters_append value
    open(BONDING_MASTERS, 'a') {|f| f << value}
  end

  def bond_slave_modify bond, value
    bond_slaves_file = File.join(NET_CLASS, bond, 'bonding', 'slaves')
    open(bond_slaves_file, 'a') {|f| f << value}
  end

  def get_bond_slaves bond
    slaves_file = File.join NET_CLASS, bond, 'bonding', 'slaves'
    File.read(slaves_file).split
  end

end
