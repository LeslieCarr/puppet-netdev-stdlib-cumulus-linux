module CanAccessInterfaces
  NETWORK_INTERFACES = '/etc/newtork/interfaces'

  def all_interfaces
    @interfaces ||= {}
  end

  def all_mapping
    @mapping ||={}
  end

  def all_source
    @source ||=[]
  end

  def self.clear
    @interfaces = {}
    @mapping = {}
    @source = []
  end

  def interface name
    if all_interfaces[name]
      intf = all_interfaces[name]
    else
      intf = Interface.new(name)
      all_interfaces[name] = intf
    end
    intf
  end

  # def self.[](name)
  #   if all_interfaces[name]
  #     interface = all_interfaces[name]
  #   else
  #     interface = Interface.new(name)
  #     all_interfaces[name] = interface
  #   end
  #   interface
  # end

  def self.parse(file=NETWORK_INTERFACES)
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
        currently_processing = interface(name)
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
        if @mapping[glob]
          mapping = @mapping[glob]
        else
          mapping = Mapping.new(glob)
          @mapping[glob] = mapping
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
        ups.each { |i| interface(i).onboot = true }
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
        @source << src
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
          else
            currently_processing.options[key] << value
          end
        when Mapping
        end
      end
    end
    @interfaces
  end

  def self.header
    "# This file is generated"
  end

  def self.flush(file=NETWORK_INTERFACES)
    # Flush content to file
    content = "%{header}\n\n%{auto}\n\n%{interface}\n\n%{mapping}\n%{source}\n" %
    {
      :header => header,
      :auto => all_interfaces.select { |k, v| v.onboot == true }.collect { |k, v| k }.join(" "),
      :interface => all_interfaces.collect { |k, v| v.to_formatted_s }.join("\n"),
      :mapping => all_mapping.collect { |i| i.to_formatted_s }.join("\n"),
      :source => all_sources.collect { |i| "source #{i}" }.join("\n")
    }
    content
  end


  class Mapping
    # just to make interface file parsing consistent
    attr_reader :glob

    def initialize(glob)
      @glob = glob
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
      @options = Hash.new { |hash, key| hash[key] = [] }
    end
  end


end
