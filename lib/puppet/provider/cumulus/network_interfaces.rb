class NetworkInterfaces
  NETWORK_INTERFACES = '/etc/network/interfaces'


  def all_interfaces
    @interfaces ||= {}
  end

  def all_mapping
    @mapping ||={}
  end

  def all_sources
    @sources ||=[]
  end

  def clear
    @interfaces = {}
    @mapping = {}
    @sources = []
  end

  def [](name)
    if all_interfaces[name]
      interface = all_interfaces[name]
    else
      interface = Interface.new(name)
      all_interfaces[name] = interface
    end
    interface
  end

  def header
    "# This file is generated"
  end

  def flush(file=NETWORK_INTERFACES)
    # Flush content to file
    content = "%s\n\nauto %s\n\n%s\n\n%s\n%s\n" %
    [
      header,
      all_interfaces.select { |k, v| v.onboot == true }.collect { |k, v| k }.join(" "),
      all_interfaces.collect { |k, v| v.to_formatted_s }.join("\n\n"),
      all_mapping.collect { |i| i.to_formatted_s }.join("\n"),
      all_sources.collect { |i| "source #{i}" }.join("\n")
    ]
    File.open(file, 'w') { |f| f.write(content) }
  end

  class << self

    def parse(file=NETWORK_INTERFACES)
      network_interfaces = new
      #The file consists of zero or more "iface", "mapping", "auto", "allow-" and "source" stanzas.
      currently_processing = nil
      multiline = []
      lines = File.readlines(file)
      lines.each do |line|
        line = line.strip
        next if line.empty?

        if not multiline.empty?
          line = (multiline << line).join ' '
          multiline.clear
        end

        case line
        when /^#/
          # Lines  starting  with  `#'  are ignored. Note that end-of-line
          # comments are NOT supported, comments must  be  on  a  line  of
          # their own.
          next
        when /(.+)\\$/
          # A  line  may  be  extended across multiple lines by making the
          # last character a backslash.
          multiline << $1
          next
        when /^iface/
          # Stanzas defining logical interfaces start with a line consist‐
          # ing of the word "iface" followed by the name  of  the  logical
          # interface. The interface name is  followed
          # by  the  name  of  the address family that the interface uses.
          # This will be "inet" for TCP/IP networking, but there  is  also
          # some  support  for IPX networking ("ipx"), and IPv6 networking
          # ("inet6").  Following that is the name of the method  used  to
          # configure the interface. Additional  options  can  be  given
          # on subsequent lines in the stanza.
          _, name, family, method = line.split
          currently_processing = network_interfaces[name]
          currently_processing.family = family
          currently_processing.method = method
        when /^mapping/
          # Stanzas  beginning  with the word "mapping" are used to deter‐
          # mine how a logical interface name is  chosen  for  a  physical
          # interface  that is to be brought up.  The first line of a map‐
          # ping stanza consists of the word "mapping" followed by a  pat‐
          # tern in shell glob syntax.  Each mapping stanza must contain a
          # script definition.  The named script is run with the  physical
          # interface  name  as  its argument and with the contents of all
          # following "map" lines  (without  the  leading  "map")  in  the
          # stanza  provided  to it on its standard input.
          #
          _, glob = line.split(/\s+/, 2)
          if network_interfaces.all_mapping[glob]
            mapping = network_interfaces.all_mapping[glob]
          else
            mapping = Mapping.new(glob)
            network_interfaces.all_mapping[glob] = mapping
          end
          currently_processing = mapping
        when /^auto|^allow-auto/
          # Lines  beginning with the word "auto" are used to identify the
          # physical interfaces to be brought up...
          # Physical interface names should follow the word "auto" on  the
          # same line.  There can be multiple "auto" stanzas.
          # Note that "allow-auto"  and "auto" are synonyms
          ups = line.split
          ups.shift
          ups.each { |i| network_interfaces[i].onboot = true }
          currently_processing = nil
        when /^allow\-/
          next
        when /^source/
          # Lines beginning with "source" are used to include stanzas from
          # other files, so configuration can be split  into  many  files.
          # The  word  "source"  is  followed  by  the  path of file to be
          # sourced.
          src = line.split
          src.shift
          network_interfaces.all_sources << src
        else
          # Process data that belongs to current stanza
          case currently_processing
          when Interface
            key, value = line.split(/\s+/, 2)
            case key
            when 'address'
              currently_processing.ip_address = value
            when 'netmask'
              currently_processing.netmask = value
            when 'mtu'
              currently_processing.mtu = value
            when 'gateway'
              currently_processing.gateway = value
            when 'pre-up'
              case value
              when /ethtool/
                if value =~ /-s\s+(.*)/
                  Hash[$1.split.each_slice(2).to_a].each_pair do |k,v|
                    if currently_processing.respond_to? "#{k}="
                      currently_processing.send("#{k}=", v)
                    end
                  end
                else
                  currently_processing.options[key] << value
                end
              else
                currently_processing.options[key] << value
              end
            else
              currently_processing.options[key] << value
            end
          when Mapping
          end
        end
      end
      network_interfaces # @interfaces
    end

    private :new
  end

end


class Interface
  attr_reader :name
  attr_accessor :up, :speed, :mtu, :duplex,
    :ip_address, :netmask, :gateway, :method,
    :family, :onboot, :hotplug, :options

  def initialize(name)
    @name = name
    @onboot = false
    @method = 'dhcp'
    @family = 'inet'
    @options = Hash.new { |hash, key| hash[key] = [] }
  end

  def to_formatted_s
    out = []
    out << "iface #{name} #{family} #{method}"

    {
      :ip_address => 'address',
      :netmask => 'netmask',
      :mtu => 'mtu'
    }.each do |property, section|
      out << "  #{section} #{self.send property}" if self.send(property)
    end

    if duplex || speed
      options = ["  pre-up /sbin/ethtool #{name} -s"]
      options << "speed #{speed}" if speed
      options << "duplex #{duplex}" if duplex
      out << options.join(" ")
    end

    if self.options
      self.options.each_pair do |key, val|
        if val.is_a? String
          stanza << "  #{key} #{val}"
        elsif val.is_a? Array
          out << "  #{key} #{val.uniq.sort.join ' '}"
          # val.each { |entry| out << "  #{key} #{entry}" }
        end
      end
    end
    out.join("\n")
  end

  def to_s
    to_formatted_s
  end
end

class LinkSpeed

  class << self
    @@speed = {
      :_10m => {:netdev => "10m", :ethtool => "10"},
      :_100m => {:netdev => "100m", :ethtool => "100"},
      :_1g => {:netdev => "1g", :ethtool => "1000"},
      :_10g => {:netdev => "10g", :ethtool => "10000"},
      :_40g => {:netdev => "40g", :ethtool => "40000"},
      :auto => {:netdev => :auto, :ethtool => nil}
    }

    def to_netdev(speed)
      parse(speed)[:netdev]
    end

    def to_ethtool(speed)
      parse(speed)[:ethtool]
    end


    def parse(speed)
      s = case speed
      when '10Mb/s', '10m'
        :_10m
      when '100Mb/s', '100m'
        :_100m
      when '1000Mb/s', '1g'
        :_1g
      when '10000Mb/s', '10g'
        :_10g
      when '40000Mb/s', '10g'
        :_40g
      else
        :auto
      end
      @@speed[s]
    end

    private :new, :parse
  end

end

class Duplex

  class << self

    def to_netdev(value)
    end
    def to_ethtool(value)
    end
    def parse(value)
    end
    private :new, :parse
  end
end


class Mapping
  # just to make interface file parsing consistent
  attr_reader :glob

  def initialize(glob)
    @glob = glob
  end

  def to_formatted_s
  end

end

class Bridge < Interface

  def initialize(name)
    super(name)
    @ports = []
  end
end

class Vlan < Bridge
end

class Bond < Interface
end

class Lag < Interface
end
