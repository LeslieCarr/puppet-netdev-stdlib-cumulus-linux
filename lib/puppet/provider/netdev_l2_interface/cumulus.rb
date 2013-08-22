$LOAD_PATH.unshift(File.join(File.dirname(__FILE__),"..","..",".."))
require 'puppet/provider/cumulus/cumulus_parent'
require 'puppet/provider/cumulus/network_interfaces'

Puppet::Type.type(:netdev_l2_interface).provide(:cumulus, :parent => Puppet::Provider::Cumulus) do

  commands  :iplink => '/sbin/ip', :brctl =>'/sbin/brctl'

  mk_resource_methods

  # def vlan_tagging=(value)
  #   raise "VLAN tagging is always enabled."
  # end


  def create
    begin
      # brctl(['addif', resource[:untagged_vlan], resource[:name]]) if resource[:untagged_vlan]
      resource[:tagged_vlans].flatten.each do |vlan|
        _, id = vlan.split '_'
        sub_if = "#{resource[:name]}.#{id}"
        begin
          iplink(['link', 'show', sub_if])
        rescue
          iplink(['link', 'add', 'link', resource[:name], 'name', sub_if, 'type', 'vlan', 'id', id])
        end
        brctl(['addif', vlan, sub_if])
      end if resource[:tagged_vlans]
    rescue
      #Could not create
      false
    end
  end

  def destroy
    iplink(['link', 'set', resource[:name], 'down'])
    brctl(['delbr', resource[:name]])
  end


  def self.link_master name
    iplink(['-oneline','link', 'show', name ]).match(/master\s+(\S+)/)
  end


  def apply
    brctl(['addif', resource[:untagged_vlan], resource[:name]]) if resource[:untagged_vlan]
    vlans_by_name = Hash[Puppet::Type.type(:netdev_vlan).instances.map{|vlan| [vlan[:name],vlan]}]
    resource[:tagged_vlans].each do |vlan|
      vlan = vlans_by_name[resource[:name]]
      brctl(['addif', resource[:untagged_vlan], "#{resource[:name]}.#{vlan[:vlan_id]}"]) if vlan
    end
  end

  def persist
  end


  def self.instances
    interfaces = Puppet::Type.type(:netdev_interface).instances.map {|i| i[:name]}
    bridges = Puppet::Type.type(:netdev_vlan).instances.map {|i| i[:name]}
    l2_interfaces = interfaces - bridges
    l2_interfaces.collect do |i|
      new ({:name => i,
            :vlan_tagging => :enabled,
            :untagged_vlan => link_master(i) || :absent,
            :tagged_vlans => Dir[File.join SYSFS_NET_PATH, i + '.*'].collect do |subi|
              link_master(File.basename subi)
            end,
            :ensure => :present})
    end
  end

end
