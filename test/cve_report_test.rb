# frozen_string_literal: true

require_relative "test_helper"

class CveReportTest < Minitest::Test
  def test_renders_unique_confirmed_cves_for_each_image
    results = [{
      "image" => "ghcr.io/example/app",
      "statistics" => [],
      "images" => [
        image("ghcr.io/example/app:latest", [
          section([["CVE-2026-0001", "HIGH"], ["CVE-2026-0002", "MEDIUM"], ["CVE-2026-0003", nil]]),
          section([["CVE-2026-0001", "CRITICAL"], ["GHSA-example", "HIGH"]])
        ]),
        image("ghcr.io/example/app:alpine", [], error: "missing report")
      ]
    }]

    assert_equal <<~TABLE, ContainerStatistics::CveReport.new(results).render
      CONTAINER                   CRITICAL  HIGH  MEDIUM  LOW  UNKNOWN  TOTAL
      --------------------------  --------  ----  ------  ---  -------  -----
      ghcr.io/example/app:latest         1     -       1    -        1      3
      ghcr.io/example/app:alpine         —     —       —    —        —      —
    TABLE
  end

  private

  def image(name, sections, error: nil)
    {
      "image" => name,
      "statistics" => [{"key" => "vulnerabilities", "error" => error, "sections" => sections}]
    }
  end

  def section(findings)
    {"error" => nil, "findings" => findings.map { |id, severity| {"id" => id, "severity" => severity} }}
  end
end
