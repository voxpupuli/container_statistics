# frozen_string_literal: true

module ContainerStatistics
  class ProviderRegistry
    def initialize(providers)
      @providers = providers
    end

    def provider_for(image, capability:)
      provider = @providers.find do |candidate|
        candidate.supports?(image) && candidate.respond_to?(capability)
      end
      raise Error, "No provider supports #{capability} for #{image}" unless provider

      provider
    end
  end
end
