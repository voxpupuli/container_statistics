# frozen_string_literal: true

require_relative "test_helper"

class ProviderRegistryTest < Minitest::Test
  def test_turns_an_unsupported_registry_into_a_reportable_error
    providers = ContainerStatistics::ProviderRegistry.new([])
    statistic = ContainerStatistics::Statistics::Downloads.new(providers: providers)
    result = statistic.collect("docker.io/library/ruby")

    assert_equal "unknown", result["provider"]
    assert_match(/No provider supports download_statistics/, result["error"])
  end
end
