# frozen_string_literal: true

require "fileutils"
require "json"
require "tempfile"

module ContainerStatistics
  class FileCache
    def initialize(path:, ttl:, clock: -> { Time.now })
      @path = path
      @ttl = ttl
      @clock = clock
    end

    def fetch(key)
      entries = load_entries
      now = @clock.call.to_f
      entry = entries[key]
      age = now - entry["cached_at"].to_f if entry.is_a?(Hash)
      return entry["value"] if age && age >= 0 && age < @ttl

      value = yield
      entries[key] = {"cached_at" => now, "value" => value}
      write_entries(entries)
      value
    end

    private

    def load_entries
      entries = JSON.parse(File.read(@path))
      entries.is_a?(Hash) ? entries : {}
    rescue JSON::ParserError, SystemCallError
      {}
    end

    def write_entries(entries)
      directory = File.dirname(@path)
      FileUtils.mkdir_p(directory)
      Tempfile.create(["container-statistics", ".json"], directory) do |file|
        file.write(JSON.generate(entries))
        file.flush
        file.fsync
        File.rename(file.path, @path)
      end
    rescue SystemCallError
      nil
    end
  end
end
