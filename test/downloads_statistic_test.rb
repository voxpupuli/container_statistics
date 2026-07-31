# frozen_string_literal: true

require_relative "test_helper"

class DownloadsStatisticTest < Minitest::Test
  class Provider
    def name
      "Example registry"
    end

    def supports?(_image)
      true
    end

    def download_statistics(_image)
      {
        "provider" => name,
        "downloads" => 200,
        "url" => "https://example.test/package"
      }
    end
  end

  def test_normalizes_provider_data_for_the_general_report
    providers = ContainerStatistics::ProviderRegistry.new([Provider.new])
    result = ContainerStatistics::Statistics::Downloads.new(providers: providers).collect("example/image")

    assert_equal "downloads", result["key"]
    assert_equal 200, result["value"]
    assert_nil result["details"]
  end

  def test_caches_provider_results
    provider = Provider.new
    providers = ContainerStatistics::ProviderRegistry.new([provider])
    cache = Object.new
    def cache.fetch(_key)
      {"provider" => "Cached registry", "downloads" => 123, "url" => "https://example.test/cached"}
    end

    result = ContainerStatistics::Statistics::Downloads.new(providers: providers, cache: cache).collect("example/image")

    assert_equal 123, result["value"]
    assert_equal "Cached registry", result["provider"]
  end
end
