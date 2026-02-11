# app/services/google_sheet_service.rb
require 'google/apis/sheets_v4'
require 'googleauth'

class GoogleSheetService
  SCOPE = Google::Apis::SheetsV4::AUTH_SPREADSHEETS_READONLY
  CREDENTIALS_PATH = Rails.root.join('config', 'google_credentials.json')

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

    begin
      puts "Reading #{ranges_to_fetch.length} ranges..."

      response = @service.batch_get_spreadsheet_values(spreadsheet_id, ranges: ranges_to_fetch)

      response.value_ranges.each do |value_range|
        range_name = value_range.range
        values = value_range.values || []

        puts "Successfully read #{values.length} rows from range: #{range_name}."
        all_data[range_name] = values
      end

      all_data
    rescue StandardError => e
      puts "Error when call Google Sheets API (batch_get): #{e.message}"
      Rails.logger.error "GoogleSheetService: Error API (batch_get): #{e.message}"
      nil
    end
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
    response = @service.get_spreadsheet_values(spreadsheet_id, range_name)

    response.values || []
  rescue StandardError => e
    puts "Error when call Google Sheets API (get_data): #{e.message}"
    Rails.logger.error "GoogleSheetService: Error API (get_data): #{e.message}"
    nil
  end

  def get_all_sheet_names(spreadsheet_id)
    response = @service.get_spreadsheet(spreadsheet_id, fields: 'sheets(properties.title)')
    response.sheets.map { |sheet| ensure_utf8(sheet.properties.title) }
  rescue StandardError => e
    puts "Error when get sheet names: #{e.message}"
    Rails.logger.error "GoogleSheetService: Error get sheet names: #{e.message}"
    nil
  end

  def get_sheets_info(spreadsheet_id)
    response = @service.get_spreadsheet(spreadsheet_id, fields: 'sheets(properties(title,sheetId))')
    response.sheets.map do |sheet|
      {
        title: ensure_utf8(sheet.properties.title),
        sheet_id: sheet.properties.sheet_id.to_s
      }
    end
  rescue StandardError => e
    puts "Error when get sheets info: #{e.message}"
    Rails.logger.error "GoogleSheetService: Error get sheets info: #{e.message}"
    nil
  end

  private

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
