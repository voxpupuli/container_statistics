# frozen_string_literal: true

module ContainerStatistics
  class TextReport
    CONTAINER_HEADING = "CONTAINER"
    DOWNLOADS_HEADING = "TOTAL DOWNLOADS"

    def initialize(results)
      @results = results
    end

    def render
      rows = @results.map do |result|
        downloads = result["statistics"].find { |statistic| statistic["key"] == "downloads" }
        [result["image"], number(downloads&.fetch("value", nil))]
      end
      container_width = ([CONTAINER_HEADING.length] + rows.map { |row| row.first.length }).max
      downloads_width = ([DOWNLOADS_HEADING.length] + rows.map { |row| row.last.length }).max

      lines = [format_row(CONTAINER_HEADING, DOWNLOADS_HEADING, container_width, downloads_width)]
      lines << format_row("-" * container_width, "-" * downloads_width, container_width, downloads_width)
      rows.each { |row| lines << format_row(row.first, row.last, container_width, downloads_width) }
      "#{lines.join("\n")}\n"
    end

    private

    def format_row(container, downloads, container_width, downloads_width)
      "#{container.ljust(container_width)}  #{downloads.rjust(downloads_width)}"
    end

    def number(value)
      return "—" if value.nil?

      value.to_i.to_s.reverse.scan(/.{1,3}/).join(",").reverse
    end
  end
end
