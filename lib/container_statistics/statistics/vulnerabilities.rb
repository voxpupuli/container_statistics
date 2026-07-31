# frozen_string_literal: true

require "json"
require "date"
require "time"

module ContainerStatistics
  module Statistics
    class Vulnerabilities
      SEVERITIES = %w[CRITICAL HIGH MEDIUM LOW UNKNOWN].freeze
      SEVERITY_RANK = SEVERITIES.each_with_index.to_h.freeze
      FILTERED_GRYPE_NAMESPACE = "nvd:cpe"

      def initialize(report_dir:)
        @report_dir = report_dir
        @report_ids = load_manifest(File.join(report_dir, "manifest.tsv"))
      end

      def collect(image)
        report_id = @report_ids[image]
        raise Error, "No vulnerability scan result exists for #{image}" unless report_id

        trivy = read_json(File.join(@report_dir, "#{report_id}.trivy.json"))
        grype = read_json(File.join(@report_dir, "#{report_id}.grype.json"))
        {
          "key" => "vulnerabilities",
          "label" => "Vulnerabilities",
          "value" => nil,
          "unit" => nil,
          "provider" => "Trivy and Grype",
          "url" => nil,
          "error" => nil,
          "metadata" => {"built_date" => trivy_image_build_date(trivy)},
          "sections" => [scanner_payload("Trivy", trivy), scanner_payload("Grype", grype)]
        }
      rescue Error => e
        error_statistic(e.message)
      end

      private

      def load_manifest(path)
        File.readlines(path, chomp: true).to_h do |line|
          report_id, image = line.split("\t", 2)
          raise Error, "Invalid vulnerability manifest entry: #{line}" if report_id.to_s.empty? || image.to_s.empty?

          [image, report_id]
        end
      rescue Errno::ENOENT => e
        raise Error, "Vulnerability manifest not found: #{e.message}"
      end

      def read_json(path)
        JSON.parse(File.read(path))
      rescue Errno::ENOENT, JSON::ParserError => e
        {"scan_error" => "Invalid or missing scanner output: #{e.message}"}
      end

      def trivy_image_build_date(report)
        image_config = report.dig("Metadata", "ImageConfig") || {}
        created = image_config["created"] || image_config["Created"]
        return nil unless created.is_a?(String)

        date = Time.iso8601(created).to_date
        date == Date.new(1, 1, 1) ? nil : date.iso8601
      rescue ArgumentError
        nil
      end

      def scanner_payload(name, report)
        findings = name == "Trivy" ? trivy_findings(report) : grype_findings(report)
        filtered_findings = []
        if name == "Grype"
          filtered_findings, findings = findings.partition do |finding|
            finding["namespace"] == FILTERED_GRYPE_NAMESPACE
          end
        end
        findings.sort_by! { |finding| SEVERITY_RANK.fetch(finding["severity"]) }
        filtered_findings.sort_by! { |finding| SEVERITY_RANK.fetch(finding["severity"]) }

        {
          "label" => name,
          "error" => report["scan_error"],
          "counts" => severity_counts(findings),
          "findings" => findings,
          "filtered_counts" => severity_counts(filtered_findings),
          "filtered_findings" => filtered_findings
        }
      end

      def trivy_findings(report)
        (report["Results"] || []).flat_map do |result|
          target = result["Target"].to_s
          (result["Vulnerabilities"] || []).map do |vulnerability|
            {
              "id" => vulnerability["VulnerabilityID"].to_s,
              "package" => vulnerability["PkgName"].to_s,
              "installed" => vulnerability["InstalledVersion"].to_s,
              "fixed" => vulnerability["FixedVersion"].to_s,
              "severity" => normalize_severity(vulnerability["Severity"]),
              "title" => vulnerability["Title"].to_s,
              "target" => target,
              "url" => vulnerability["PrimaryURL"].to_s
            }
          end
        end
      end

      def grype_findings(report)
        (report["matches"] || []).map do |match|
          vulnerability = match["vulnerability"] || {}
          artifact = match["artifact"] || {}
          locations = artifact["locations"] || []
          {
            "id" => vulnerability["id"].to_s,
            "package" => artifact["name"].to_s,
            "installed" => artifact["version"].to_s,
            "fixed" => (vulnerability.dig("fix", "versions") || []).map(&:to_s).join(", "),
            "severity" => normalize_severity(vulnerability["severity"]),
            "title" => vulnerability["description"].to_s,
            "target" => locations.first&.fetch("path", "").to_s,
            "url" => vulnerability["dataSource"].to_s,
            "namespace" => vulnerability["namespace"].to_s
          }
        end
      end

      def normalize_severity(value)
        severity = value.to_s.upcase
        SEVERITIES.include?(severity) ? severity : "UNKNOWN"
      end

      def severity_counts(findings)
        counts = findings.map { |finding| finding["severity"] }.tally
        SEVERITIES.to_h { |severity| [severity, counts.fetch(severity, 0)] }.reject { |_severity, count| count.zero? }
      end

      def error_statistic(message)
        {
          "key" => "vulnerabilities",
          "label" => "Vulnerabilities",
          "value" => nil,
          "unit" => nil,
          "provider" => "Trivy and Grype",
          "url" => nil,
          "error" => message,
          "metadata" => {},
          "sections" => []
        }
      end
    end
  end
end
