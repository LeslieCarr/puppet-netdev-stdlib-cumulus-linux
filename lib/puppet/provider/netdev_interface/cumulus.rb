require File.join(File.dirname(__FILE__), '..', '..', '..', 'puppet_x', 'cumulus', 'interfaces.rb')
Puppet::Type.type(:netdev_interface).provide(:cumulus) do

  commands :ethtool  => '/sbin/ethtool',
    :iplink => '/sbin/ip'

  mk_resource_methods

  def initialize(value={})
    super(value)
    @property_flush = {}
  end

  def exists?
    @property_hash[:ensure] == :present
  end

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

  def flush
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
      (eth_options << 'speed' << netdev_to_speed(resource[:speed])) if @property_flush[:speed]
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
    @property_hash = resource.to_hash
  end

  ###### Util methods ######

  SPEED_ALLOWED_VALUES = ['auto','10m','100m','1g','10g']
  DUPLEX_ALLOWED_VALUES = ['auto', 'full', 'half']

  def netdev_to_speed value
    case value
    when '10m'
      10
    when '100m'
      100
    when '1g'
      1000
    when '10g'
      10000
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
        speed = speed ? speed_to_netdev(speed): :absent
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

    def prefetch(resources)
      interfaces = instances
      resources.each do |name, params|
        if provider = interfaces.find { |interface| interface.name == params[:name] }
          resources[name].provider = provider
        end
      end
    end

    def speed_to_netdev value
      case value
      when /^unknown/i
        'auto'
      when /(\d+)Mb\/s/i
        speed_int = $1.to_i
        if speed_int < 1000
          "#{speed_int}m"
        elsif speed_int >= 1000
          "#{speed_int / 1000}g"
        end
      else
        raise TypeError, "Speed must be one of the values [#{SPEED_ALLOWED_VALUES.join ','}]"
      end
    end

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
