# frozen_string_literal: true

require_relative "test_helper"

class TextReportTest < Minitest::Test
  def test_renders_only_container_and_total_download_columns
    results = [
      result("ghcr.io/example/first", 12_345),
      result("ghcr.io/example/second", nil)
    ]

    output = ContainerStatistics::TextReport.new(results).render

    assert_equal <<~TABLE, output
      CONTAINER               TOTAL DOWNLOADS
      ----------------------  ---------------
      ghcr.io/example/first            12,345
      ghcr.io/example/second                —
    TABLE
  end

  private

  def result(image, downloads)
    {
      "image" => image,
      "statistics" => [{"key" => "downloads", "value" => downloads}]
    }
  end
end
