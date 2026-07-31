# frozen_string_literal: true

require_relative "test_helper"

class ReportTest < Minitest::Test
  def test_renders_registered_statistics_details_and_errors
    results = [
      {
        "image" => "ghcr.io/voxpupuli/voxbox",
        "statistics" => [{
          "key" => "downloads",
          "label" => "Downloads",
          "value" => 12_345,
          "unit" => "downloads",
          "provider" => "GitHub Container Registry",
          "url" => "https://example.test/voxbox",
          "error" => nil,
          "details" => {
            "label" => "Package versions",
            "columns" => ["Version", "Downloads"],
            "rows" => [["latest", 10_000]]
          }
        }, {
          "key" => "example",
          "label" => "Example metric",
          "value" => 42,
          "unit" => "items",
          "provider" => "Example provider",
          "url" => nil,
          "error" => nil,
          "details" => nil
        }],
        "images" => [{
          "image" => "ghcr.io/voxpupuli/voxbox:latest",
          "statistics" => [{
            "key" => "vulnerabilities",
            "label" => "Vulnerabilities",
            "value" => nil,
            "unit" => nil,
            "provider" => "Trivy and Grype",
            "url" => nil,
            "error" => nil,
            "metadata" => {"built_date" => "2026-07-30"},
            "sections" => [{
              "label" => "Trivy",
              "error" => nil,
              "counts" => {"CRITICAL" => 1},
              "findings" => [finding("CVE-2026-0001", "CRITICAL")],
              "filtered_counts" => {},
              "filtered_findings" => []
            }, {
              "label" => "Grype",
              "error" => nil,
              "counts" => {},
              "findings" => [],
              "filtered_counts" => {"HIGH" => 1},
              "filtered_findings" => [finding("CVE-2026-0002", "HIGH")]
            }]
          }]
        }]
      },
      {
        "image" => "docker.io/library/ruby",
        "statistics" => [{
          "key" => "downloads",
          "label" => "Downloads",
          "value" => nil,
          "unit" => "downloads",
          "provider" => "unknown",
          "url" => nil,
          "error" => "unsupported",
          "details" => nil
        }]
      }
    ]

    html = ContainerStatistics::Report.new(results, clock: -> { Time.utc(2026, 7, 31, 12) }).render

    assert_includes html, "container statistics"
    assert_includes html, "12,345"
    assert_includes html, "latest"
    assert_includes html, "Example metric"
    assert_includes html, "combined example metric"
    refute_includes html, "available statistics"
    assert_includes html, "unsupported"
    assert_includes html, "ghcr.io/voxpupuli/voxbox:latest (2026-07-30)"
    assert_includes html, "CVE-2026-0001"
    assert_includes html, "CVE-2026-0002"
    assert_includes html, "NVD/CPE filtered 1"
    assert_includes html, "id=\"severity\""
    assert_includes html, "2026-07-31T12:00:00Z"
  end

  private

  def finding(id, severity)
    {
      "id" => id,
      "package" => "openssl",
      "installed" => "1.0",
      "fixed" => "1.1",
      "severity" => severity,
      "title" => "Example issue",
      "target" => "app",
      "url" => "https://example.test/#{id}"
    }
  end
end
