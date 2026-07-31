# frozen_string_literal: true

require "net/http"
require "uri"

module ContainerStatistics
  class HttpClient
    MAX_REDIRECTS = 5

    def get(url, redirects: MAX_REDIRECTS, retries: 2, cookies: {})
      uri = URI(url)
      request = Net::HTTP::Get.new(uri)
      request["User-Agent"] = "container-statistics"
      request["Cookie"] = cookies.map { |key, value| "#{key}=#{value}" }.join("; ") unless cookies.empty?
      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
        http.request(request)
      end
      response_cookies = cookies.merge(extract_cookies(response))

      case response
      when Net::HTTPSuccess
        response.body
      when Net::HTTPRedirection
        raise Error, "Too many redirects while requesting #{url}" if redirects.zero?

        get(
          URI.join(url, response.fetch("location")).to_s,
          redirects: redirects - 1,
          retries: retries,
          cookies: response_cookies
        )
      else
        if response.code.to_i >= 500 && retries.positive?
          return get(url, redirects: redirects, retries: retries - 1, cookies: response_cookies)
        end

        raise HttpError.new("HTTP #{response.code} while requesting #{url}", status: response.code.to_i)
      end
    rescue URI::InvalidURIError => e
      raise Error, "Invalid URL #{url}: #{e.message}"
    rescue SystemCallError, SocketError => e
      raise Error, "HTTP request failed for #{url}: #{e.message}"
    end

    private

    def extract_cookies(response)
      (response.get_fields("set-cookie") || []).to_h do |header|
        header.split(";", 2).first.split("=", 2)
      end
    end
  end
end
