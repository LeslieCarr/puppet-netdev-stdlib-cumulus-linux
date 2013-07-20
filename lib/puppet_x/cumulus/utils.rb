module Puppet::PuppetX::Cumulus

  class Utils
    class << self
      def value text, key, separator='\s+'
        $1 if text =~ /#{key}#{separator}/i
      end
    end
  end
end
