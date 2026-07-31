# frozen_string_literal: true

require "tmpdir"
require_relative "test_helper"

class FileCacheTest < Minitest::Test
  def test_reuses_values_for_24_hours_and_refreshes_expired_entries
    Dir.mktmpdir do |directory|
      now = Time.utc(2026, 7, 31, 12)
      path = File.join(directory, "downloads.json")
      cache = ContainerStatistics::FileCache.new(path: path, ttl: 86_400, clock: -> { now })

      assert_equal({"downloads" => 10}, cache.fetch("example") { {"downloads" => 10} })
      assert_equal({"downloads" => 10}, cache.fetch("example") { flunk("cache miss") })

      now += 86_400
      assert_equal({"downloads" => 20}, cache.fetch("example") { {"downloads" => 20} })
    end
  end

  def test_replaces_an_invalid_cache_file
    Dir.mktmpdir do |directory|
      path = File.join(directory, "downloads.json")
      File.write(path, "not JSON")
      cache = ContainerStatistics::FileCache.new(path: path, ttl: 86_400)

      assert_equal({"downloads" => 10}, cache.fetch("example") { {"downloads" => 10} })
    end
  end
end
