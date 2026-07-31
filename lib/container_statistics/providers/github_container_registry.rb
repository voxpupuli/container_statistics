# frozen_string_literal: true

require "cgi"

module ContainerStatistics
  module Providers
    class GitHubContainerRegistry
      def initialize(client:)
        @client = client
      end

      def name
        "GitHub Container Registry"
      end

      def supports?(image)
        image.split("/", 2).first == "ghcr.io"
      end

      def download_statistics(image)
        owner, package_name = coordinates(image)
        url, html = fetch_package_page(owner, package_name)

        {
          "image" => "ghcr.io/#{owner}/#{package_name}",
          "provider" => name,
          "downloads" => total_downloads(html),
          "url" => url,
          "error" => nil
        }
      end

      private

      def coordinates(image)
        reference = image.sub(/@.+\z/, "")
        path = reference.delete_prefix("ghcr.io/")
        path = path.sub(%r{:[^/]+\z}, "")
        owner, package_name = path.split("/", 2)
        raise Error, "Invalid GitHub container image: #{image}" if owner.to_s.empty? || package_name.to_s.empty?

        [owner, package_name]
      end

      def fetch_package_page(owner, package_name)
        escaped_name = CGI.escapeURIComponent(package_name)
        urls = [
          "https://github.com/orgs/#{owner}/packages/container/package/#{escaped_name}",
          "https://github.com/#{owner}/packages/container/package/#{escaped_name}"
        ]

        urls.each do |url|
          return [url, @client.get(url)]
        rescue HttpError => e
          raise unless e.status == 404
        end

        raise Error, "GitHub package #{owner}/#{package_name} was not found or is not publicly accessible"
      end

      def total_downloads(html)
        match = html.match(%r{>Total downloads</span>\s*<h3 title="([\d,]+)">}i)
        raise Error, "GitHub package page does not contain a total download count" unless match

        integer(match[1])
      end

      def integer(value)
        value.delete(",").to_i
      end
    end
  end
end
