# frozen_string_literal: true

module ContainerStatistics
  class CveReport
    CONTAINER_HEADING = "CONTAINER"
    SEVERITIES = ContainerStatistics::Statistics::Vulnerabilities::SEVERITIES
    HEADINGS = [CONTAINER_HEADING, *SEVERITIES, "TOTAL"].freeze

    def initialize(results)
      @results = results
    end

    def render
      rows = @results.flat_map do |result|
        result.fetch("images", []).map do |image|
          vulnerabilities = image["statistics"].find { |statistic| statistic["key"] == "vulnerabilities" }
          counts = cve_counts(vulnerabilities)
          values = if counts
                     [*SEVERITIES.map { |severity| counts.fetch(severity, 0) }, counts.values.sum]
                   else
                     [nil] * (SEVERITIES.length + 1)
                   end
          [image["image"], *values.map { |value| number(value) }]
        end
      end
      widths = HEADINGS.each_index.map do |index|
        ([HEADINGS[index].length] + rows.map { |row| row[index].length }).max
      end

      lines = [format_row(HEADINGS, widths)]
      lines << format_row(widths.map { |width| "-" * width }, widths)
      rows.each { |row| lines << format_row(row, widths) }
      "#{lines.join("\n")}\n"
    end

    private

    def cve_counts(statistic)
      return nil if statistic.nil? || statistic["error"]

      sections = statistic.fetch("sections", []).reject { |section| section["error"] }
      return nil if sections.empty?

      severities_by_cve = {}
      sections.flat_map { |section| section.fetch("findings", []) }.each do |finding|
        id = finding["id"].to_s.upcase
        next unless id.start_with?("CVE-")

        severity = finding["severity"].to_s.upcase
        severity = "UNKNOWN" unless SEVERITIES.include?(severity)
        current = severities_by_cve[id]
        if current.nil? || severity_rank(severity) < severity_rank(current)
          severities_by_cve[id] = severity
        end
      end
      severities_by_cve.values.tally
    end

    def severity_rank(severity)
      SEVERITIES.index(severity)
    end

    def format_row(values, widths)
      values.each_with_index.map do |value, index|
        index.zero? ? value.ljust(widths[index]) : value.rjust(widths[index])
      end.join("  ")
    end

    def number(value)
      return "—" if value.nil?
      return "-" if value.zero?

      value.to_i.to_s.reverse.scan(/.{1,3}/).join(",").reverse
    end
  end
end
