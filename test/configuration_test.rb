# frozen_string_literal: true

require "tempfile"
require_relative "test_helper"

class ConfigurationTest < Minitest::Test
  def test_loads_packages_and_expands_tags
    file = yaml_file(<<~YAML)
      ---
      containers:
        - name: VoxPupuli/VoxBox
          registry: GHCR.IO
          tags:
            - alpine
            - latest
    YAML

    container = ContainerStatistics::Configuration.load_containers(file.path).first

    assert_equal "ghcr.io/voxpupuli/voxbox", container.package_reference
    assert_equal [
      "ghcr.io/voxpupuli/voxbox:alpine",
      "ghcr.io/voxpupuli/voxbox:latest"
    ], container.image_references
  ensure
    File.unlink(file.path) if file && File.exist?(file.path)
  end

  def test_allows_a_package_without_scan_tags
    file = yaml_file("---\ncontainers:\n  - name: example/app\n    registry: ghcr.io\n")

    container = ContainerStatistics::Configuration.load_containers(file.path).first

    assert_empty container.image_references
  ensure
    File.unlink(file.path) if file && File.exist?(file.path)
  end

  def test_rejects_duplicate_packages
    file = yaml_file(<<~YAML)
      ---
      containers:
        - name: example/app
          registry: ghcr.io
        - name: example/app
          registry: ghcr.io
    YAML

    error = assert_raises(ContainerStatistics::Error) do
      ContainerStatistics::Configuration.load_containers(file.path)
    end

    assert_match(/Duplicate containers/, error.message)
  ensure
    File.unlink(file.path) if file && File.exist?(file.path)
  end

  private

  def yaml_file(content)
    Tempfile.create(["containers", ".yml"]).tap do |file|
      file.write(content)
      file.close
    end
  end
end
