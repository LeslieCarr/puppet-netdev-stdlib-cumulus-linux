$LOAD_PATH.unshift(File.join(File.dirname(__FILE__),"..","..",".."))
require 'puppet/provider/cumulus/cumulus_parent'
require 'puppet/provider/cumulus/network_interfaces'

Puppet::Type.type(:netdev_interface).provide(:cumulus, :parent => Puppet::Provider::Cumulus) do

  commands :ethtool  => '/sbin/ethtool', :iplink => '/sbin/ip'

  mk_resource_methods

  def create
    # raise NotImplementedError "Interface creation is not implemented."
    exists? ? (return true) : (return false)

  end

  def destroy
    # raise NotImplementedError "Interface destruction is not implemented."
    exists? ? (return false) : (return true)
  end

  def admin=(value)
    @property_flush[:admin] = value
  end

  def mtu=(value)
    @property_flush[:mtu] = value
  end

  def speed=(value)
    @property_flush[:speed] = value
  end

  def duplex=(value)
    @property_flush[:duplex] = value
  end

  def apply
    ip_options = []
    eth_options = []
    if @property_flush
      (ip_options << resource[:admin]) if @property_flush[:admin]
      (ip_options << 'mtu' << resource[:mtu]) if @property_flush[:mtu]
    end
    unless ip_options.empty?
      ip_options.unshift ['link', 'set', resource[:name]]
      iplink ip_options
    end

    if @property_flush
      (eth_options << 'speed' << LinkSpeed.to_ethtool(resource[:speed])) if @property_flush[:speed]
      case @property_flush[:duplex]
      when 'full', 'half'
        (eth_options << 'duplex' << resource[:duplex] << 'autoneg' << 'off')
      when 'auto'
        (eth_options << 'autoneg' << 'on')
      end
    end
    unless eth_options.empty?
      eth_options.unshift ['-s', resource[:name]]
      ethtool eth_options
    end
  end

  def persist
    if @property_flush
      network_interfaces = NetworkInterfaces.parse
      res_net_interface = network_interfaces[resource[:name]]
      res_net_interface.onboot = true if @property_flush[:admin]
      res_net_interface.mtu = resource[:mtu] if @property_flush[:mtu]
      res_net_interface.speed = LinkSpeed.to_ethtool(@property_flush[:speed]) if @property_flush[:speed]
      res_net_interface.duplex = resource[:duplex] if @property_flush[:duplex]
      network_interfaces.flush
    end
  end

  class << self

    def instances
      iplink(['-oneline','link','show']).lines.select {|i| /link\/ether/ =~ i}.
      each.collect do |intf|
        _, name, params = intf.split(':', 3).map {|c| c.strip }
        name, _ = name.split '@' #take care of the sub-interfaces in format "eth1.100@eth1"
        out = ethtool(name)
        duplex = value(out, 'duplex', ':')
        duplex = duplex ? duplex_to_netdev(duplex) : :absent
        speed = value(out, 'speed', ':')
        speed = speed ? LinkSpeed.to_netdev(speed): :absent
        new(:name => name,
            :description => name,
            :mtu => value(params, 'mtu').to_i,
            :up => value(params, 'state').downcase,
            :duplex => duplex,
            :speed => speed,
            :ensure => :present
            )
      end
    end

    DUPLEX_ALLOWED_VALUES = ['auto', 'full', 'half']

    def duplex_to_netdev value
      value = value.downcase
      if DUPLEX_ALLOWED_VALUES.include? value
        value
      else
        raise TypeError, "Duplex must be one of the values [#{DUPLEX_ALLOWED_VALUES.join ','}]"
      end

    end

    def value text, key, separator=''
      if text =~ /#{key}#{separator}\s*(\S*)/i
        $1
      end
    end

  end

end
