# frozen_string_literal: true

require_relative "test_helper"

class ResultErrorsTest < Minitest::Test
  def test_collects_package_image_and_scanner_errors_with_context
    results = [{
      "image" => "ghcr.io/example/package",
      "statistics" => [statistic("Downloads", "download failed")],
      "images" => [{
        "image" => "ghcr.io/example/package:latest",
        "statistics" => [statistic("Vulnerabilities", nil, [{"label" => "Trivy", "error" => "scan failed"}])]
      }]
    }]

    assert_equal [
      "ghcr.io/example/package / Downloads: download failed",
      "ghcr.io/example/package:latest / Vulnerabilities / Trivy: scan failed"
    ], ContainerStatistics::ResultErrors.collect(results)
  end

  private

  def statistic(label, error, sections = [])
    {"label" => label, "error" => error, "sections" => sections}
  end
end
