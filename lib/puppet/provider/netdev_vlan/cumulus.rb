Puppet::Type.type(:netdev_vlan).provide(:cumulus) do

  commands :brctl =>'/sbin/brctl',
           :iplink => '/sbin/ip'

  SYSFS_NET_PATH = "/sys/class/net"
  NAME_SEP = '_'

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

  def name=(value)
    raise "VLAN can not be renamed."
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  class << self

    def instances
      bridges = Dir[File.join SYSFS_NET_PATH, '*'].
        select{|dir| File.directory? File.join dir, 'bridge'}.
        collect{|br| File.basename br }
      bridges.each.collect do |bridge_name|
        _, vlan = bridge_name.split NAME_SEP
        vlan_id = vlan ? vlan.to_i : :absent
        new ({:ensure => :present,
              :name => bridge_name,
              :vlan_id => vlan_id})
      end
    end
  end

end
