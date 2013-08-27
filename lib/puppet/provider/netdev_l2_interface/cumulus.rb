$LOAD_PATH.unshift(File.join(File.dirname(__FILE__),"..","..",".."))
require 'puppet/provider/cumulus/cumulus_parent'
require 'puppet/provider/cumulus/network_interfaces'

Puppet::Type.type(:netdev_l2_interface).provide(:cumulus, :parent => Puppet::Provider::Cumulus) do

  commands  :iplink => '/sbin/ip', :brctl =>'/sbin/brctl',
    :ethtool  => '/sbin/ethtool'

  mk_resource_methods

  def untagged_vlan=(value)
    @property_flush[:untagged_vlan] = value
  end

  def tagged_vlans=(value)
    @property_flush[:tagged_vlans] = value
  end

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


  def apply
    brctl(['addif', @property_flush[:untagged_vlan], resource[:name]]) if @property_flush[:untagged_vlan]
    vlans = bridges
    @property_flush[:tagged_vlans].each do |vlan_name|
      vlan = vlans.find {|b| b[:name] == vlan_name}
      brctl(['addif', @property_flush[:tagged_vlans], "#{resource[:name]}.#{vlan[:vlan_id]}"]) if vlan
    end if @property_flush[:tagged_vlans]
  end

  def persist
    Puppet.debug("persist -> @property_flush[:tagged_vlans]=#{@property_flush[:tagged_vlans]}")
    if @property_flush
      network_interfaces = NetworkInterfaces.parse
      if @property_flush[:untagged_vlan]
        vlan = network_interfaces[@property_flush[:untagged_vlan]]
        vlan.options['bridge_ports'] << resource[:name]
      end

      vlans = bridges
      @property_flush[:tagged_vlans].each do |vlan_name|
        Puppet.debug("persist tagged_vlan=#{tagged_vlan}")
        vlan = vlans.find {|b| b[:name] == vlan_name}
        vlan_intf = network_interfaces[vlan_name]
        vlan_intf.options['bridge_ports'] << "#{resource[:name]}.#{vlan[:vlan_id]}"
      end if @property_flush[:tagged_vlans]
      network_interfaces.flush
    end
  end


  def self.instances
    l2_interfaces.collect { |i| new(i) }
  end

end
