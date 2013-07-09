Puppet::Type.type(:netdev_vlan).provide(:cumulus) do

  commands :brctl =>'/sbin/brctl'

  mk_resource_methods

  def create
    brctl(['addbr', resource[:name]])
  end

  def destroy
    brctl(['delbr', resource[:name]])
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  class << self

    def instances
      bridges = brctl('show').lines[1..-1]
      bridges.each.collect do |br|
        name, id, stp, interfaces = br.split
        new ({:name => name,
              :ensure => :present})
      end
    end
  end

end
