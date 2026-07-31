# frozen_string_literal: true

module ContainerStatistics
  class Error < StandardError; end

  class HttpError < Error
    attr_reader :status

    def initialize(message, status:)
      super(message)
      @status = status
    end
  end
end

require_relative "container_statistics/configuration"
require_relative "container_statistics/file_cache"
require_relative "container_statistics/http_client"
require_relative "container_statistics/provider_registry"
require_relative "container_statistics/providers/github_container_registry"
require_relative "container_statistics/report"
require_relative "container_statistics/result_errors"
require_relative "container_statistics/statistics/downloads"
require_relative "container_statistics/statistics/vulnerabilities"
require_relative "container_statistics/cve_report"
require_relative "container_statistics/text_report"
