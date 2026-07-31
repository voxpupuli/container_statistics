# frozen_string_literal: true

module ContainerStatistics
  module Statistics
    class Downloads
      def initialize(providers:, cache: nil)
        @providers = providers
        @cache = cache
      end

      def collect(image)
        provider = @providers.provider_for(image, capability: :download_statistics)
        data = if @cache
                 @cache.fetch("#{provider.name}:#{image}") { provider.download_statistics(image) }
               else
                 provider.download_statistics(image)
               end

        {
          "key" => "downloads",
          "label" => "Downloads",
          "value" => data["downloads"],
          "unit" => "downloads",
          "provider" => data["provider"],
          "url" => data["url"],
          "error" => nil,
          "details" => nil
        }
      rescue Error => e
        {
          "key" => "downloads",
          "label" => "Downloads",
          "value" => nil,
          "unit" => "downloads",
          "provider" => provider&.name || "unknown",
          "url" => nil,
          "error" => e.message,
          "details" => nil
        }
      end

    end
  end
end
