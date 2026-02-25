# app/services/google_sheet_service.rb
require 'google/apis/sheets_v4'
require 'googleauth'

class GoogleSheetService
  SCOPE = Google::Apis::SheetsV4::AUTH_SPREADSHEETS_READONLY
  CREDENTIALS_PATH = Rails.root.join('config', 'google_credentials.json')
  QUOTA_RETRY_WAIT = 65 # seconds to wait when quota is exceeded (limit resets per minute)
  MAX_RETRIES = 3

  def initialize
    @service = Google::Apis::SheetsV4::SheetsService.new
    @service.authorization = authorize
  end

  def get_project_test_cases(spreadsheet_id)
    puts "Start processing file: #{spreadsheet_id}"
    all_sheet_names = get_all_sheet_names(spreadsheet_id)

    unless all_sheet_names&.any?
      puts 'Error: Cannot find any sheet in the file.'
      return nil
    end

    puts "Found #{all_sheet_names.length} sheets: #{all_sheet_names.join(', ')}"
    process_all_sheets(spreadsheet_id, all_sheet_names)
  end

  def get_specific_sheet_data(spreadsheet_id, ranges_to_fetch)
    return nil unless ranges_to_fetch.is_a?(Array)

    all_data = {}

    puts "Reading #{ranges_to_fetch.length} ranges..."

    response = with_quota_retry('batch_get') do
      @service.batch_get_spreadsheet_values(spreadsheet_id, ranges: ranges_to_fetch)
    end
    return nil unless response

    response.value_ranges.each do |value_range|
      range_name = value_range.range
      values = value_range.values || []

      puts "Successfully read #{values.length} rows from range: #{range_name}."
      all_data[range_name] = values
    end

    all_data
  end

  def get_filtered_sheet_data(spreadsheet_id, sheet_name, columns_range, options = {})
    @current_options = options
    puts "Filtering sheet '#{sheet_name}'..."

    full_range = determine_range(sheet_name, columns_range)
    puts "Getting data from range: '#{full_range}'"

    raw_rows = get_data(spreadsheet_id, full_range)
    return nil if raw_rows.nil?

    filter_raw_rows(raw_rows)
  rescue StandardError => e
    puts "Error when filtering (get_filtered_sheet_data): #{e.message}"
    Rails.logger.error "GoogleSheetService: Error filtering: #{e.message}"
    nil
  end

  def get_data(spreadsheet_id, range_name)
    response = with_quota_retry('get_data') do
      @service.get_spreadsheet_values(spreadsheet_id, range_name)
    end
    return nil unless response

    response.values || []
  end

  def get_all_sheet_names(spreadsheet_id)
    response = with_quota_retry('get_sheet_names') do
      @service.get_spreadsheet(spreadsheet_id, fields: 'sheets(properties.title)')
    end
    return nil unless response

    response.sheets.map { |sheet| ensure_utf8(sheet.properties.title) }
  end

  def get_sheets_info(spreadsheet_id)
    response = with_quota_retry('get_sheets_info') do
      @service.get_spreadsheet(spreadsheet_id, fields: 'sheets(properties(title,sheetId))')
    end
    return nil unless response

    response.sheets.map do |sheet|
      {
        title: ensure_utf8(sheet.properties.title),
        sheet_id: sheet.properties.sheet_id.to_s
      }
    end
  end

  private

  # Retry block when Google Sheets quota is exceeded.
  # Waits 65 seconds (quota resets per minute) then retries up to MAX_RETRIES times.
  def with_quota_retry(operation)
    retries = 0
    begin
      yield
    rescue Google::Apis::RateLimitError => e
      retries += 1
      if retries <= MAX_RETRIES
        puts "  [QUOTA] #{operation}: Rate limit hit. Waiting #{QUOTA_RETRY_WAIT}s... (retry #{retries}/#{MAX_RETRIES})"
        sleep(QUOTA_RETRY_WAIT)
        retry
      else
        puts "  [QUOTA] #{operation}: Max retries exceeded. #{e.message}"
        Rails.logger.error "GoogleSheetService: Quota exceeded after #{MAX_RETRIES} retries: #{e.message}"
        nil
      end
    rescue Google::Apis::Error => e
      puts "Error in #{operation}: #{e.message}"
      Rails.logger.error "GoogleSheetService: Error in #{operation}: #{e.message}"
      nil
    end
  end

  def process_all_sheets(spreadsheet_id, all_sheet_names)
    filter_options = {
      header_rows_count: 4,
      filter_column_index: 1,
      valid_filter_values: %w[Feature Data UI]
    }

    result = all_sheet_names.each_with_object({}) do |sheet_name, all_filtered_data|
      puts "Processing sheet: '#{sheet_name}'"
      all_filtered_data[sheet_name] = get_filtered_sheet_data(
        spreadsheet_id, sheet_name, nil, filter_options
      )
    end
    puts 'Processing completed'
    result
  end

  def determine_range(sheet_name, columns_range)
    if columns_range.nil? || columns_range.empty?
      sheet_name
    else
      "#{sheet_name}!#{columns_range}"
    end
  end

  def filter_raw_rows(raw_rows)
    header_rows_count = @current_options.fetch(:header_rows_count, 4)
    filter_column_index = @current_options.fetch(:filter_column_index, 1)
    valid_filter_values = @current_options.fetch(:valid_filter_values, %w[Feature Data UI])

    # Include header rows (1-4)
    clean_data = raw_rows.first(header_rows_count)

    # Include row 5 (device names row) if it exists
    if raw_rows.length > header_rows_count
      device_names_row = raw_rows[header_rows_count]
      clean_data << device_names_row
      puts "Including device names row (row #{header_rows_count + 1}): #{device_names_row.inspect}"
    end

    # Filter data rows starting from row 6
    data_rows = raw_rows.drop(header_rows_count + 1)
    filtered_rows = data_rows.filter do |row|
      cell_value = row[filter_column_index]
      cell_value.present? && valid_filter_values.include?(cell_value.strip)
    end

    clean_data.concat(filtered_rows)
    puts_filter_summary(clean_data.length, header_rows_count)
    clean_data
  end

  def puts_filter_summary(total_rows, header_count)
    msg = "Filtering completed. Total #{total_rows} rows " \
          "(including #{header_count} header rows + 1 device names row)."
    puts msg
  end

  def authorize
    unless File.exist?(CREDENTIALS_PATH)
      puts "Cannot find credentials file at: #{CREDENTIALS_PATH}"
      puts 'Please download the JSON file of the Service Account from Google Cloud Console.'
      raise 'Missing Google Credentials File'
    end

    Google::Auth::ServiceAccountCredentials.make_creds(
      json_key_io: File.open(CREDENTIALS_PATH),
      scope: SCOPE
    )
  end

  def ensure_utf8(str)
    return nil if str.nil?

    # Force to UTF-8 and scrub invalid sequences
    str.to_s.force_encoding('UTF-8').scrub
  end
end
