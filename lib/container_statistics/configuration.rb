# frozen_string_literal: true

require "yaml"

module ContainerStatistics
  class ContainerDefinition
    attr_reader :name, :registry, :tags

    def initialize(name:, registry:, tags:)
      @name = name
      @registry = registry
      @tags = tags.freeze
    end

    def package_reference
      "#{registry}/#{name}"
    end

    def image_references
      tags.map { |tag| "#{package_reference}:#{tag}" }
    end
  end

  module Configuration
    module_function

    def load_containers(path)
      document = YAML.safe_load_file(path, permitted_classes: [], permitted_symbols: [], aliases: false)
      entries = document.is_a?(Hash) ? document["containers"] : nil
      raise Error, "Configuration must contain a containers array" unless entries.is_a?(Array)

      containers = entries.each_with_index.map { |entry, index| build_container(entry, index) }
      raise Error, "Container configuration is empty" if containers.empty?

      duplicates = containers.group_by(&:package_reference).select { |_package, values| values.length > 1 }.keys
      raise Error, "Duplicate containers: #{duplicates.join(", ")}" unless duplicates.empty?

      containers
    rescue Errno::ENOENT => e
      raise Error, "Container configuration not found: #{e.message}"
    rescue Psych::Exception => e
      raise Error, "Invalid container configuration: #{e.message}"
    end

    def build_container(entry, index)
      position = "containers[#{index}]"
      raise Error, "#{position} must be a mapping" unless entry.is_a?(Hash)

      registry = required_string(entry, "registry", position).downcase.delete_suffix("/")
      name = required_string(entry, "name", position).downcase
      tags = entry.fetch("tags", [])
      raise Error, "#{position}.tags must be an array" unless tags.is_a?(Array)
      raise Error, "#{position}.registry must not include a URL scheme" if registry.include?("://")
      unless name.match?(%r{\A[a-z0-9._-]+/[a-z0-9._/-]+\z})
        raise Error, "#{position}.name must contain a valid namespace and package without a tag"
      end

      normalized_tags = tags.map.with_index do |tag, tag_index|
        unless tag.is_a?(String) && tag.match?(/\A[\w][\w.-]{0,127}\z/)
          raise Error, "#{position}.tags[#{tag_index}] must be a valid string tag"
        end

        tag
      end
      duplicate_tags = normalized_tags.tally.select { |_tag, count| count > 1 }.keys
      raise Error, "#{position} contains duplicate tags: #{duplicate_tags.join(", ")}" unless duplicate_tags.empty?

      ContainerDefinition.new(name: name, registry: registry, tags: normalized_tags)
    end
    private_class_method :build_container

    def required_string(entry, key, position)
      value = entry[key]
      raise Error, "#{position}.#{key} must be a non-empty string" unless value.is_a?(String) && !value.strip.empty?

      value.strip
    end
    private_class_method :required_string
  end
end
