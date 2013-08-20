class Puppet::Provider::Cumulus < Puppet::Provider

  def apply
    ## Apply runtime configuration
    Puppet.debug("'apply' was not implemented.")
  end

  def persist
    # Persist configuration
    Puppet.debug("'persist' was not implemented.")
  end

  def flush
    apply
    persist
    @property_hash = resource.to_hash
  end

  class << self
    def prefetch(resources)
      interfaces = instances
      resources.each do |name, params|
        if provider = interfaces.find { |interface| interface.name == params[:name] }
          resources[name].provider = provider
        end
      end
    end
  end

end
