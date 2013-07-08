Puppet::Type.type(:netdev_interface).provide(:cumulus) do

  commands :ifconfig => '/sbin/ifconfig',
    :ethtool  => '/sbin/ethtool'

  mk_resource_methods

  def exists?
    @property_hash[:ensure] == :present
  end

  def self.instances
    def get_value text, key
      if text =~ /#{key}:\s*(.*)/i
        $1
      end
    end

    self.split_interfaces(ifconfig('-a')).
      select {|i| /encap\:ethernet/im =~ i }.
    each.collect do |infs|
      /^(\S+)/ =~ infs
      name = $1
      flags = {:name => name}
      infs.split("\n").each { |line|
        if /MTU\:\d+\s+Metric\:/ =~ line
          #Parse Flags
          intf_flags = line.strip.split
          flags[:metric] =  intf_flags.pop.split(':')[1].to_i
          flags[:mtu] =  intf_flags.pop.split(':')[1].to_i
          flags[:flags] = intf_flags
          flags[:up] = flags[:flags].include?('UP')
        end
      }
      out = ethtool(name)
      flags[:duplex] =  get_value(out, 'duplex')
      flags[:speed] =  get_value(out, 'speed')

      new(:name => flags[:name],
          :description => flags[:name],
          :mtu => flags[:mtu],
          :up => self.boolean_to_updown(flags[:up]),
          :duplex => self.duplex_to_netdev(flags[:duplex]),
          :speed => self.speed_to_netdev(flags[:speed]),
          :ensure => :present
          )
    end
  end

  def self.preferch(resources)
    interfaces = instances
    resources.each do |name, params|
      if provider = interfaces.find { |interface| interface.name == params[:name] }
        resources[name].provider = provider
      end
    end
  end

  def self.split_interfaces(text)
    ifaces = []
    text.split("\n").each { |line|
      ifaces[ifaces.length] = "" if line =~ /^\S/
      ifaces[ifaces.length-1] += line.rstrip+"\n"
    }
    return ifaces
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
    ifconfig(resource[:name], value)
  end

  def mtu=(value)
    ifconfig(resource[:name], 'mtu', value)
  end

  def speed=(value)
    ethtool('-s', resource[:name], 'speed', netdev_to_speed(value)) if value != :auto
  end

  def duplex=(value)
    ethtool('-s', resource[:name], 'duplex', value) if value != :auto
  end

  ###### Util methods ######

  def flags
    self.interface_flags ifconfig(resource[:name]), ethtool(resource[:name])
  end

  def self.interface_flags ifconfig_txt, ethtool_text
    out = ifconfig_txt # ifconfig(resource[:name])
    flags = {}
    out.split("\n").each { |line|
      if /MTU\:\d+\s+Metric\:/ =~ line
        #Parse Flags
        intf_flags = line.strip.split
        flags[:metric] =  intf_flags.pop.split(':')[1].to_i
        flags[:mtu] =  intf_flags.pop.split(':')[1].to_i
        flags[:flags] = intf_flags
        flags[:up] = flags[:flags].include?('UP')
      end
    }
    out = ethtool_text #ethtool(resource[:name])
    flags[:duplex] = duplex_to_netdev self.get_value(out, 'duplex')
    flags[:speed] =  speed_to_netdev self.get_value(out, 'speed')

    flags
  end

  def self.get_value text, key
    if text =~ /#{key}:\s*(.*)/i
      $1
    end
  end

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

  def self.speed_to_netdev value
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

  def self.duplex_to_netdev value
    value = value.downcase
    if DUPLEX_ALLOWED_VALUES.include? value
      value
    else
      raise TypeError, "Duplex must be one of the values [#{DUPLEX_ALLOWED_VALUES.join ','}]"
    end

  end

  def self.boolean_to_updown(value)
    value ? 'up' : 'down'
  end

end
