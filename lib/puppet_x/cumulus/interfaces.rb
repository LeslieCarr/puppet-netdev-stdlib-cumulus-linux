module PuppetX::Cumulus
  class Interface
    attr_reader :iface_name, :family_name, :method_name
    attr_accessor :option

    def initialize name, family, method
      @iface_name = name
      @family_name = family
      @method_name = method
      @option = {}
    end

    def to_s
      output = []
      output << "iface #{@iface_name} #{@family_name} #{@method_name}"
      @option.each do |key, value|
        if value.is_a? Array
          value.each do |v|
            output << "\t#{key} #{v}"
          end
        else
          output << "\t#{key} #{value}"
        end
      end
      output.join "\n"
    end

  end


  class InterfacesFile

    INTERFACES_FILE = '/etc/network/interfaces'

    attr_accessor :data

    def initialize file=INTERFACES_FILE
      @file = file
      @data = parse file
    end

    def parse
      interfaces = {}
      currently_processing = nil
      allow_ups = []
      File.readlines(@file).each do |line|
        line = line.strip
        next if line.empty?
        case line
        when /^#/
          #skip comments
          next
        when /^mapping\s/
          next
        when /^iface\s/
          _, iface_name, address_family_name, method_name = line.split
          currently_processing = Interface.new iface_name, address_family_name, method_name
          interfaces[iface_name] = currently_processing
        when /^auto\s/
          _, *ups = line.split
          allow_ups << ups
          currently_processing = nil
        when /^allow-/
          currently_processing = nil
        else
          case currently_processing
          when Interface
            case line
            when /^up\s/, /^down\s/
              key, *value = line.split(/\s/,2)
              currently_processing.option[key] ||= []
              currently_processing.option[key] << value
            when /^pre\-up\s/, /^post-down\s/
              key, value = line.split(/\s/,2)
              currently_processing.option[key] = value
            else
              key, value = line.split
              currently_processing.option[key] = value
            end
          end
        end
      end
      {:interfaces => interfaces.values, :allow_up => allow_ups.flatten.uniq}
    end

    def to_s
      output = []
      output << "auto #{@data[:allow_up].join(' ')}" if @data[:allow_up]
      @data[:interfaces].each { |i| output << i } if @data[:interfaces]
      output.join "\n"
    end
  end
end


puts InterfacesFile.new '/Users/sergey/work/interfaces'
