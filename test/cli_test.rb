# frozen_string_literal: true

require "open3"
require "rbconfig"
require "tmpdir"
require_relative "test_helper"

class CliTest < Minitest::Test
  def test_prints_collected_errors_with_context
    Dir.mktmpdir do |directory|
      stdout, stderr, status = Open3.capture3(
        RbConfig.ruby,
        File.expand_path("../bin/container-statistics", __dir__),
        "--input",
        File.expand_path("fixtures/containers-without-tags.yml", __dir__),
        "--download-cache",
        File.join(directory, "downloads.json"),
        "--download-report"
      )

      assert status.success?
      assert_includes stdout, "example.test/example/service"
      assert_includes stderr, "Errors:"
      assert_includes stderr, "example.test/example/service / Downloads:"
      assert_includes stderr, "No provider supports download_statistics"
    end
  end
end
