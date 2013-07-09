Puppet::Type.type(:netdev_l2_interface).provide(:cumulus) do

  commands  :iplink => '/sbin/ip'

  mk_resource_methods

  def exists?
    @property_hash[:ensure] == :present
  end

  class << self
    def link_master name
      iplink(['-oneline','link', 'show', name ]).match(/master\s+(\S+)/)
    end

    def instances
      interfaces = Puppet::Type.type(:netdev_interface).instances.map {|i| i[:name]}
      bridges = Puppet::Type.type(:netdev_vlan).instances.map {|i| i[:name]}
      l2_interfaces = interfaces - bridges
      l2_interfaces.collect do |i|
        new ({:name => i,
              :untagged_vlan => link_master(i) || :absent,
              :tagged_vlans => Dir[File.join SYSFS_NET_PATH, i + '.*'].collect do |subi|
                link_master(File.basename subi)
              end,
              :ensure => :present})

      end
    end
  end
end
