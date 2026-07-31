# frozen_string_literal: true

require "tmpdir"
require_relative "test_helper"

class VulnerabilitiesStatisticTest < Minitest::Test
  def test_normalizes_scanners_build_date_and_filtered_cpe_matches
    Dir.mktmpdir do |directory|
      write_reports(directory)
      statistic = ContainerStatistics::Statistics::Vulnerabilities.new(report_dir: directory)

      result = statistic.collect("example.test/app:1")

      assert_equal "2026-07-30", result.dig("metadata", "built_date")
      trivy, grype = result["sections"]
      assert_equal ["CVE-CRITICAL", "CVE-LOW"], trivy["findings"].map { |finding| finding["id"] }
      assert_equal({"CRITICAL" => 1, "LOW" => 1}, trivy["counts"])
      assert_equal ["CVE-HIGH"], grype["findings"].map { |finding| finding["id"] }
      assert_equal ["CVE-CPE"], grype["filtered_findings"].map { |finding| finding["id"] }
      assert_equal({"CRITICAL" => 1}, grype["filtered_counts"])
    end
  end

  def test_turns_a_missing_image_result_into_a_statistic_error
    Dir.mktmpdir do |directory|
      File.write(File.join(directory, "manifest.tsv"), "image-001\texample.test/app:1\n")
      statistic = ContainerStatistics::Statistics::Vulnerabilities.new(report_dir: directory)

      result = statistic.collect("example.test/other:1")

      assert_match(/No vulnerability scan result exists/, result["error"])
    end
  end

  private

  def write_reports(directory)
    File.write(File.join(directory, "manifest.tsv"), "image-001\texample.test/app:1\n")
    File.write(File.join(directory, "image-001.trivy.json"), JSON.generate(trivy_report))
    File.write(File.join(directory, "image-001.grype.json"), JSON.generate(grype_report))
  end

  def trivy_report
    {
      "Metadata" => {"ImageConfig" => {"created" => "2026-07-30T05:42:17.123456789Z"}},
      "Results" => [{
        "Target" => "app",
        "Vulnerabilities" => [
          {"VulnerabilityID" => "CVE-LOW", "Severity" => "Low"},
          {"VulnerabilityID" => "CVE-CRITICAL", "Severity" => "Critical"}
        ]
      }]
    }
  end

  def grype_report
    {
      "matches" => [
        {
          "vulnerability" => {"id" => "CVE-HIGH", "severity" => "High"},
          "artifact" => {"name" => "libxml", "version" => "1.0"}
        },
        {
          "vulnerability" => {
            "id" => "CVE-CPE",
            "namespace" => "nvd:cpe",
            "severity" => "Critical"
          },
          "artifact" => {"name" => "git", "version" => "2.0"}
        }
      ]
    }
  end
end
