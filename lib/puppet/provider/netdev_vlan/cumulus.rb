Puppet::Type.type(:netdev_vlan).provide(:cumulus) do

  commands :brctl =>'/sbin/brctl',
    :iplink => '/sbin/ip'

  SYSFS_NET_PATH = "/sys/class/net"
  NAME_SEP = '_'
  DEFAULT_AGING_TIME = 300

  mk_resource_methods

  def create
    unless resource[:name] =~ /^\w+#{NAME_SEP}\d+/
      raise ArgumentError, "VLAN name must be in format <name>#{NAME_SEP}<VLAN ID>"
    end
    brctl(['addbr', resource[:name]])
    iplink(['link', 'set', 'dev', resource[:name], 'up'])
  end

  def destroy
    brctl(['delbr', resource[:name]])
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  def description=(value)
    raise "Can not modify VLAN description"
  end

  def active=(value)
    status = value ? 'up': 'down'
    iplink(['link', 'set', 'dev', resource[:name], status])
  end

  def name=(value)
    raise "VLAN can not be renamed."
  end

  def no_mac_learning=(value)
    #To disable mac learning set ageing time to zero
    #Otherwise set to default (300 seconds)
    brctl(['setageing', resource[:name], value ? 0 : DEFAULT_AGING_TIME])
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
              :description => bridge_name,
              :no_mac_learning => (aging_time.to_i) / 100 == 0,
              :vlan_id => vlan_id})
      end
    end

    def prefetch(resources)
      interfaces = instances
      resources.each do |name, params|
        if provider = interfaces.find { |interface| interface.name == params[:name] }
          resources[name].provider = provider
        end
      end
    end
  end

end
