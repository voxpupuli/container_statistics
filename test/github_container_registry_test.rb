# frozen_string_literal: true

require_relative "test_helper"

class GitHubContainerRegistryTest < Minitest::Test
  PACKAGE_HTML = <<~HTML
    <main>
      <li class="Box-row">
        <a class="Label Label--success mr-1" href="?tag=latest">latest</a>
        <a class="Label mr-1" href="?tag=1.2.3">1.2.3</a>
        1,234
        <span class="sr-only">Version downloads</span>
      </li>
      <li class="Box-row extra-class">
        <a class="Label mr-1" href="?tag=old">old&amp;stable</a>
        5
        <span class="sr-only">Version downloads</span>
      </li>
      <span class="d-block color-fg-muted text-small tmp-mb-1">Total downloads</span>
      <h3 title="123456">123K</h3>
    </main>
  HTML

  class FakeClient
    attr_reader :urls

    def initialize(html: PACKAGE_HTML, organization_missing: false)
      @html = html
      @organization_missing = organization_missing
      @urls = []
    end

    def get(url)
      @urls << url
      if @organization_missing && url.include?("/orgs/")
        raise ContainerStatistics::HttpError.new("not found", status: 404)
      end

      @html
    end
  end

  def test_extracts_total_and_recent_version_downloads
    client = FakeClient.new
    provider = ContainerStatistics::Providers::GitHubContainerRegistry.new(client: client)

    result = provider.download_statistics("ghcr.io/voxpupuli/voxbox:latest")

    assert_equal "ghcr.io/voxpupuli/voxbox", result["image"]
    assert_equal 123_456, result["downloads"]
    assert_includes client.urls.first, "/orgs/voxpupuli/"
  end

  def test_falls_back_to_a_user_package_page
    client = FakeClient.new(organization_missing: true)
    provider = ContainerStatistics::Providers::GitHubContainerRegistry.new(client: client)

    result = provider.download_statistics("ghcr.io/example/image")

    assert_equal 2, client.urls.length
    assert_equal "https://github.com/example/packages/container/package/image", result["url"]
  end

  def test_reports_a_changed_or_missing_download_element
    client = FakeClient.new(html: "<html></html>")
    provider = ContainerStatistics::Providers::GitHubContainerRegistry.new(client: client)

    error = assert_raises(ContainerStatistics::Error) do
      provider.download_statistics("ghcr.io/voxpupuli/voxbox")
    end

    assert_match(/does not contain a total download count/, error.message)
  end

  def test_supports_only_ghcr_images
    provider = ContainerStatistics::Providers::GitHubContainerRegistry.new(client: FakeClient.new)

    assert provider.supports?("ghcr.io/voxpupuli/voxbox")
    refute provider.supports?("docker.io/library/ruby")
  end
end
