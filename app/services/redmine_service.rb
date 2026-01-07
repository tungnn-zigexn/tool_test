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
