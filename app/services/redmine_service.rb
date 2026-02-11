require 'faraday'
require 'json'

class RedmineService
  BASE_URL = 'https://dev.zigexn.vn'.freeze
  API_KEY = ENV['REDMINE_API_KEY'].freeze
  USERNAME = ENV['REDMINE_USERNAME'].freeze
  PASSWORD = ENV['REDMINE_PASSWORD'].freeze

  # GET /projects.json - list projects (id, name, identifier)
  def self.get_projects_list
    conn = connection
    response = conn.get('/projects.json?limit=1000')
    return [] unless response.success?

    parsed = safe_parse_json(response)
    return [] if parsed.nil?

    projects = parsed['projects'] || []
    projects.map { |p| { id: p['id'], name: p['name'].to_s, identifier: p['identifier'].to_s } }
  rescue JSON::ParserError, Faraday::Error => e
    Rails.logger.error "RedmineService: get_projects_list #{e.message}"
    []
  end

  # GET /projects/:id_or_identifier.json - single project (id or identifier like "usedcar-ex")
  def self.get_project(id_or_identifier)
    return nil if id_or_identifier.blank?

    conn = connection
    id_escaped = CGI.escape(id_or_identifier.to_s)
    response = conn.get("/projects/#{id_escaped}.json")
    return nil unless response.success?

    parsed = safe_parse_json(response)
    return nil if parsed.nil?

    parsed['project']
  rescue JSON::ParserError, Faraday::Error => e
    Rails.logger.error "RedmineService: get_project #{e.message}"
    nil
  end

  # Resolve project id: if input is numeric return as-is, else fetch by identifier and return id.
  def self.resolve_project_id(id_or_identifier)
    return nil if id_or_identifier.blank?

    str = id_or_identifier.to_s.strip
    return str if str.match?(/\A\d+\z/)

    project = get_project(str)
    project ? project['id'].to_s : nil
  end

  def self.get_issues(issue_id)
    conn = connection
    response = conn.get("/issues/#{issue_id}.json")

    if response.success?
      parsed_json = safe_parse_json(response)
      parsed_json ? parsed_json['issue'] : nil
    else
      parsed = (safe_parse_json(response) rescue {})
      errors = Array(parsed['errors']).join(', ')
      Rails.logger.error "RedmineService: API error #{response.status} #{errors}"
      puts "Error when call API Redmine: #{response.status} #{errors}"
      nil
    end
  rescue Faraday::Error => e
    puts "Error when connect to Redmine: #{e.message}"
    Rails.logger.error "RedmineService: Error getting issues: #{e.message}"
    nil
  end

  # Build issues URL with optional filters: project_id, date range (created_on)
  # Returns path + query (e.g. "/issues.json?limit=100&..."). Use with BASE_URL for full URL.
  def self.build_issues_url(base_url, limit: 100, offset: 0, project_id: nil, created_on_from: nil, created_on_to: nil)
    uri = URI(base_url)
    base_path = uri.path.presence || "/"
    path = if base_path.end_with?('.json')
             base_path
           elsif base_path == "/" || base_path.empty?
             "/issues.json"
           else
             "#{base_path}.json"
           end
    
    query_params = []
    query_params << uri.query if uri.query.present?
    query_params << "limit=#{limit}&offset=#{offset}"
    query_params << "project_id=#{project_id}" if project_id.present?
    
    if created_on_from.present? && created_on_to.present?
      query_params << "created_on=#{CGI.escape("><#{created_on_from}|#{created_on_to}")}"
    elsif created_on_from.present?
      query_params << "created_on=#{CGI.escape(">=#{created_on_from}")}"
    elsif created_on_to.present?
      query_params << "created_on=#{CGI.escape("<=#{created_on_to}")}"
    end
    
    path + (path.include?('?') ? '&' : '?') + query_params.join('&')
  end

  # Fetch issues list from URL (e.g. https://dev.zigexn.vn/issues.json)
  # Optional: project_id (Redmine project ID), created_on_from, created_on_to (Date or string YYYY-MM-DD).
  # Returns { issues: [...], total_count:, offset:, limit: }
  def self.get_issues_list(url, limit: 100, offset: 0, project_id: nil, created_on_from: nil, created_on_to: nil)
    uri = URI(url)
    base_url = "#{uri.scheme}://#{uri.host}#{uri.port && uri.port != 80 && uri.port != 443 ? ":#{uri.port}" : ''}"
    from_str = created_on_from.respond_to?(:strftime) ? created_on_from.strftime('%Y-%m-%d') : created_on_from.to_s.presence
    to_str = created_on_to.respond_to?(:strftime) ? created_on_to.strftime('%Y-%m-%d') : created_on_to.to_s.presence
    path = build_issues_url(url, limit: limit, offset: offset, project_id: project_id, created_on_from: from_str, created_on_to: to_str)

    conn = connection_for_url(base_url)
    response = conn.get(path)

    if response.success?
        parsed = safe_parse_json(response)
        return nil if parsed.nil?

        {
          issues: parsed['issues'] || [],
          total_count: parsed['total_count'] || 0,
          offset: parsed['offset'] || offset,
          limit: parsed['limit'] || limit
        }
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
    connection_for_url(BASE_URL)
  end

  def self.safe_parse_json(response)
    return nil if response.nil? || response.body.blank?

    begin
      # 1. Clean up body: remove UTF-8 BOM if present
      body = response.body.to_s
      body.sub!("\xEF\xBB\xBF", "")
      
      # 2. Aggressively replace all non-breaking spaces (\u00A0) with standard spaces
      # This fixes issues where Indentation or spacing uses \u00A0 which breaks JSON.parse
      body = body.gsub("\u00A0", " ")

      # 3. Strip leading/trailing invisible characters
      body = body.strip.gsub(/\A[\u0000-\u0020]+/, '').gsub(/[\u0000-\u0020]+\z/, '')

      JSON.parse(body)
    rescue StandardError => e
      # Log the failure with the raw body snippet for debugging
      # Rescuing StandardError catches MultiJson::ParseError and other unexpected gems errors
      raw_snippet = response.body.to_s.first(200).inspect
      error_msg = "RedmineService JSON Parsing Error: #{e.message}. Status: #{response.status}. Raw body (first 200 chars): #{raw_snippet}"
      
      puts error_msg
      Rails.logger.error error_msg
      nil
    end
  end
end
