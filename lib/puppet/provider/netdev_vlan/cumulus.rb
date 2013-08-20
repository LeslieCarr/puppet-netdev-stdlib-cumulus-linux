require File.join(File.dirname(__FILE__), '..', 'cumulus', 'network_interfaces.rb')

Puppet::Type.type(:netdev_vlan).provide(:cumulus) do

  commands :brctl =>'/sbin/brctl',
    :iplink => '/sbin/ip'

  SYSFS_NET_PATH = "/sys/class/net"
  NAME_SEP = '_'
  DEFAULT_AGING_TIME = 300

  mk_resource_methods

  def initialize(value={})
    super(value)
    @property_flush = {}
    NetworkInterfaces.parse
  end

  def create
    unless resource[:name] =~ /^\w+#{NAME_SEP}\d+/
      raise ArgumentError, "VLAN name must be in format <name>#{NAME_SEP}<VLAN ID>"
    end
    brctl(['addbr', resource[:name]])
    iplink(['link', 'set', 'dev', resource[:name], 'up'])
    NetworkInterfaces[resource[:name]].family = 'inet'
    NetworkInterfaces[resource[:name]].method = 'manual'
    NetworkInterfaces[resource[:name]].onboot = true
    NetworkInterfaces[resource[:name]].options['bridge_stp'] << 'on'
    NetworkInterfaces[resource[:name]].options['bridge_maxwait'] << [20]
    NetworkInterfaces[resource[:name]].options['bridge_ageing'] << [200]
    NetworkInterfaces[resource[:name]].options['bridge_fd'] << [30]
  end

  def destroy
    brctl(['delbr', resource[:name]])
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  def name=(value)
    raise "VLAN can not be renamed."
  end

  def vlan_id=(value)
    raise "VLAN ID can not be changed."
  end

  def no_mac_learning=(value)
    #To disable mac learning set ageing time to zero
    #Otherwise set to default (300 seconds)
    # brctl(['setageing', resource[:name], value ? 0 : DEFAULT_AGING_TIME])
    @property_flush[:no_mac_learning] = value

  end

  def self.flush
    if @property_flush[:no_mac_learning]
      ageing = @property_flush[:no_mac_learning] ? 0 : DEFAULT_AGING_TIME
      brctl(['setageing', resource[:name], ageing])
      NetworkInterfaces[resource[:name]].options['bridge_ageing'] = [ageing]
    end
    NetworkInterfaces.flush
  end


  def self.instances
    bridges = Dir[File.join SYSFS_NET_PATH, '*'].
      select{|dir| File.directory? File.join dir, 'bridge'}.
      collect{|br| File.basename br }
    bridges.each.collect do |bridge_name|
      _, vlan = bridge_name.split NAME_SEP
      vlan_id = vlan ? vlan.to_i : :absent
      aging_time = File.read(File.join SYSFS_NET_PATH, bridge_name, 'bridge', 'ageing_time')
      new ({:ensure => :present,
            :name => bridge_name,
            :description => bridge_name,
            :no_mac_learning => (aging_time.to_i) / 100 == 0,
            :vlan_id => vlan_id})
    end
  end

  def self.prefetch(resources)
    interfaces = instances
    resources.each do |name, params|
      if provider = interfaces.find { |interface| interface.name == params[:name] }
        resources[name].provider = provider
      end
    end
  end

end
