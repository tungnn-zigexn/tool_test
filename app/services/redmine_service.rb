require 'faraday'
require 'json'

class RedmineService
  BASE_URL = 'https://dev.zigexn.vn'.freeze
  API_KEY = ENV['REDMINE_API_KEY'].freeze
  USERNAME = ENV['REDMINE_USERNAME'].freeze
  PASSWORD = ENV['REDMINE_PASSWORD'].freeze

  def self.get_issues(issue_id)
    conn = connection
    response = conn.get("/issues/#{issue_id}.json")

    if response.success?
      begin
        raw_body = response.body
        parsed_json = JSON.parse(raw_body)
        parsed_json['issue']
      rescue JSON::ParserError => e
        puts "Error parse JSON: #{e.message}"
        Rails.logger.error "RedmineService: error parse JSON: #{e.message}"
        nil
      end
    else
      puts %(Error when call API Redmine: #{response.status} #{response.body['errors'].join(', ')})
      nil
    end
  rescue Faraday::Error => e
    puts "Error when connect to Redmine: #{e.message}"
    Rails.logger.error "RedmineService: Error getting issues: #{e.message}"
    nil
  end

  # Fetch issues list from URL (e.g. https://dev.zigexn.vn/issues.json)
  # Supports full URL or path. Returns { issues: [...], total_count:, offset:, limit: }
  def self.get_issues_list(url, limit: 100, offset: 0)
    uri = URI(url)
    path = uri.path.end_with?('.json') ? uri.path : "#{uri.path}.json"
    path += "?#{uri.query}" if uri.query.present?
    path += (path.include?('?') ? '&' : '?') + "limit=#{limit}&offset=#{offset}"

    base_url = "#{uri.scheme}://#{uri.host}#{uri.port && uri.port != 80 && uri.port != 443 ? ":#{uri.port}" : ''}"
    conn = connection_for_url(base_url)
    response = conn.get(path)

    if response.success?
      begin
        parsed = JSON.parse(response.body)
        {
          issues: parsed['issues'] || [],
          total_count: parsed['total_count'] || 0,
          offset: parsed['offset'] || offset,
          limit: parsed['limit'] || limit
        }
      rescue JSON::ParserError => e
        Rails.logger.error "RedmineService: error parse JSON: #{e.message}"
        nil
      end
    else
      Rails.logger.error "RedmineService: API error #{response.status}"
      nil
    end
  rescue Faraday::Error, URI::InvalidURIError => e
    Rails.logger.error "RedmineService: Error fetching issues list: #{e.message}"
    nil
  end

  def self.connection_for_url(base_url = BASE_URL)
    Faraday.new(url: base_url) do |faraday|
      faraday.headers['Content-Type'] = 'application/json'
      faraday.headers['X-Redmine-API-Key'] = API_KEY
      faraday.basic_auth(USERNAME, PASSWORD)
      faraday.response :logger
      faraday.adapter Faraday.default_adapter
    end
  end

  def self.connection
    Faraday.new(url: BASE_URL) do |faraday|
      faraday.headers['Content-Type'] = 'application/json'
      faraday.headers['X-Redmine-API-Key'] = API_KEY
      faraday.basic_auth(USERNAME, PASSWORD)
      faraday.response :logger
      faraday.adapter Faraday.default_adapter
    end
  end
end
