$LOAD_PATH.unshift(File.join(File.dirname(__FILE__),"..","..",".."))
require 'puppet/provider/cumulus/cumulus_parent'
require 'puppet/provider/cumulus/network_interfaces'


Puppet::Type.type(:netdev_vlan).provide(:cumulus, :parent => Puppet::Provider::Cumulus) do

  commands :brctl => '/sbin/brctl', :iplink => '/sbin/ip'

  SYSFS_NET_PATH = "/sys/class/net"
  NAME_SEP = '_'
  DEFAULT_AGING_TIME = 300

  mk_resource_methods

  def create
    unless resource[:name] =~ /^\w+#{NAME_SEP}\d+/
      raise ArgumentError, "VLAN name must be in format <name>#{NAME_SEP}<VLAN ID>"
    end
    create_bridge(resource[:name])
  end

  def destroy
    destroy_bridge(resource[:name])
  end

  # def name=(value)
  #   raise "VLAN can not be renamed."
  # end

  # def vlan_id=(value)
  #   raise "VLAN ID can not be changed."
  # end

  def no_mac_learning=(value)
    @property_flush[:no_mac_learning] = value
  end

  def ageing
    #To disable mac learning set ageing time to zero
    #Otherwise set to default (300 seconds)
    @property_flush[:no_mac_learning] ? 0 : DEFAULT_AGING_TIME
  end

  def apply
    brctl(['setageing', resource[:name], ageing]) if @property_flush[:no_mac_learning]
  end

  def persist
    network_interfaces = NetworkInterfaces.parse
    network_interfaces[resource[:name]].options['bridge_ageing'] = [ageing]
    network_interfaces.flush
  end


  def create_bridge(name)
    brctl(['addbr', name])
    iplink(['link', 'set', 'dev', name, 'up'])

    network_interfaces = NetworkInterfaces.parse

    bridge = network_interfaces[name]
    bridge.family = 'inet'
    bridge.method = 'manual'
    bridge.onboot = true
    bridge.options['bridge_stp'] << 'on'
    bridge.options['bridge_maxwait'] << [20]
    bridge.options['bridge_ageing'] << [200]
    bridge.options['bridge_fd'] << [30]

    network_interfaces.flush
  end

  def destroy_bridge(name)
    brctl(['delbr', name])
    network_interfaces = NetworkInterfaces.parse
    network_interfaces[name] = nil
    network_interfaces.flush
  end

  class << self
    def instances
      bridges = Dir[File.join SYSFS_NET_PATH, '*'].
        select{|dir| File.directory? File.join dir, 'bridge'}.
        collect{|br| File.basename br }
      bridges.each.collect do |bridge_name|
        _, vlan = bridge_name.split NAME_SEP
        vlan_id = vlan ? vlan.to_i : :absent
        aging_time = File.read(File.join SYSFS_NET_PATH, bridge_name, 'bridge', 'ageing_time')
        new ({:ensure => :present,
              :name => bridge_name,
              # :description => bridge_name,
              :no_mac_learning => (aging_time.to_i) / 100 == 0,
              :vlan_id => vlan_id})
      end
      #  instances_by_name.collect do |name|
      #    new(:name => name, :provider => :appdmg, :ensure => :installed)
      # end
    end

  end

end
