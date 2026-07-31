# frozen_string_literal: true

require "cgi"
require "erb"
require "fileutils"
require "time"

module ContainerStatistics
  class Report
    ROOT = File.expand_path("../..", __dir__)

    def initialize(results, clock: -> { Time.now.utc })
      @results = results
      @generated = clock.call.iso8601
    end

    def write(path)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, render)
    end

    def render
      template = File.read(File.join(ROOT, "templates", "report.html.erb"))
      @stylesheet = File.read(File.join(ROOT, "assets", "report.css"))
      ERB.new(template, trim_mode: "-").result(binding)
    end

    private

    def h(value)
      CGI.escapeHTML(value.to_s)
    end

    def number(value)
      value.nil? ? "—" : value.to_i.to_s.reverse.scan(/.{1,3}/).join(",").reverse
    end

    def statistics_by_key
      @statistics_by_key ||= all_statistics
        .select { |statistic| !statistic["value"].nil? }
        .group_by { |statistic| statistic["key"] }
    end

    def all_statistics
      @results.flat_map do |result|
        result["statistics"] + result.fetch("images", []).flat_map { |image| image["statistics"] }
      end
    end

    def image_heading(image)
      build_date = image["statistics"].filter_map { |statistic| statistic.dig("metadata", "built_date") }.first
      build_date ? "#{image["image"]} (#{build_date})" : image["image"]
    end

    def package_search(result)
      values = [result["image"]]
      result["statistics"].each do |statistic|
        values.concat([statistic["label"], statistic["provider"]])
        values.concat(statistic.dig("details", "rows")&.flatten || [])
      end
      values.concat(result.fetch("images", []).map { |image| image["image"] })
      values.join(" ").downcase
    end

    def findings_table(findings)
      rows = findings.map do |finding|
        search = finding.values.join(" ").downcase
        id = if finding["url"].to_s.empty?
               h(finding["id"])
             else
               %(<a href="#{h(finding["url"])}" target="_blank" rel="noreferrer">#{h(finding["id"])}</a>)
             end
        title = [finding["title"], finding["target"]].reject(&:empty?).join(" — ")
        <<~HTML
          <tr class="finding" data-severity="#{h(finding["severity"])}" data-search="#{h(search)}">
            <td><span class="badge #{h(finding["severity"])}">#{h(finding["severity"])}</span></td>
            <td>#{id}</td><td>#{h(finding["package"])}</td><td>#{h(finding["installed"])}</td>
            <td>#{h(finding["fixed"])}</td><td>#{h(title)}</td>
          </tr>
        HTML
      end.join
      <<~HTML
        <div class="table-wrap"><table class="findings-table">
          <thead><tr>
            <th>Severity</th><th>ID</th><th>Package</th><th>Installed</th><th>Fixed</th><th>Title / target</th>
          </tr></thead>
          <tbody>#{rows}</tbody>
        </table></div>
      HTML
    end
  end
end
