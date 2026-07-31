# frozen_string_literal: true

module ContainerStatistics
  class ResultErrors
    def self.collect(results)
      results.flat_map do |result|
        errors = statistic_errors(result["image"], result["statistics"])
        result.fetch("images", []).each do |image|
          errors.concat(statistic_errors(image["image"], image["statistics"]))
        end
        errors
      end
    end

    def self.statistic_errors(context, statistics)
      statistics.flat_map do |statistic|
        label = "#{context} / #{statistic["label"]}"
        errors = []
        errors << "#{label}: #{statistic["error"]}" if statistic["error"]
        statistic.fetch("sections", []).each do |section|
          errors << "#{label} / #{section["label"]}: #{section["error"]}" if section["error"]
        end
        errors
      end
    end
    private_class_method :statistic_errors
  end
end
