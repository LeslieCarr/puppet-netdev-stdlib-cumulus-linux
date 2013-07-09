Puppet::Type.type(:netdev_l2_interface).provide(:cumulus) do

  mk_resource_methods

  def exists?
    @property_hash[:ensure] == :present
  end

  class << self
    def instances
      interfaces = Puppet::Type.type(:netdev_interface).instances.map {|i| i[:name]}
      bridges = Puppet::Type.type(:netdev_vlan).instances.map {|i| i[:name]}
      l2_interfaces = interfaces - bridges
      l2_interfaces.collect do |i|
        new ({:name => i,
              :ensure => :present})

      end
    end
  end
end
