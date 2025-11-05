# app/services/google_sheet_service.rb
require "google/apis/sheets_v4"
require "googleauth"

class GoogleSheetService
  SCOPE = Google::Apis::SheetsV4::AUTH_SPREADSHEETS_READONLY
  CREDENTIALS_PATH = Rails.root.join("config", "google_credentials.json")

  def initialize
    @service = Google::Apis::SheetsV4::SheetsService.new
    @service.authorization = authorize
  end

  def get_project_test_cases(spreadsheet_id)
    puts "Start processing file: #{spreadsheet_id}"
    all_sheet_names = get_all_sheet_names(spreadsheet_id)

    unless all_sheet_names&.any?
      puts "Error: Cannot find any sheet in the file."
      return nil
    end

    puts "Found #{all_sheet_names.length} sheets: #{all_sheet_names.join(', ')}"

    filter_options = {
      header_rows_count: 3,
      filter_column_index: 1,
      valid_filter_values: [ "Feature", "Data", "UI" ]
    }

    all_filtered_data = {}

    all_sheet_names.each do |sheet_name|
      puts "Processing sheet: '#{sheet_name}'"

      filtered_data = get_filtered_sheet_data(
        spreadsheet_id,
        sheet_name,
        nil,
        filter_options
      )

      all_filtered_data[sheet_name] = filtered_data
    end

    puts "Processing completed"
    all_filtered_data
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

    rescue Google::Apis::Error => e
      puts "Error when call Google Sheets API (batch_get): #{e.message}"
      Rails.logger.error "GoogleSheetService: Error API (batch_get): #{e.message}"
      nil
    end
  end

  def get_filtered_sheet_data(spreadsheet_id, sheet_name, columns_range, options = {})
    header_rows_count = options.fetch(:header_rows_count, 3)
    filter_column_index = options.fetch(:filter_column_index, 1)
    valid_filter_values = options.fetch(:valid_filter_values, [ "Feature", "Data", "UI" ])

    puts "Filtering sheet '#{sheet_name}'..."

    full_range = if columns_range.nil? || columns_range.empty?
                   sheet_name
    else
                   "#{sheet_name}!#{columns_range}"
    end

    puts "Getting data from range: '#{full_range}'"

    raw_rows = get_data(spreadsheet_id, full_range)

    return nil if raw_rows.nil?

    clean_data = []

    header_rows = raw_rows.first(header_rows_count)
    clean_data.concat(header_rows)

    data_rows = raw_rows.drop(header_rows_count)

    filtered_rows = data_rows.filter do |row|
      cell_value = row[filter_column_index]
      !cell_value.nil? && !cell_value.strip.empty? && valid_filter_values.include?(cell_value.strip)
    end

    clean_data.concat(filtered_rows)

    puts "Filtering completed. Total #{clean_data.length} rows (including header)."
    clean_data

  rescue => e
    puts "Error when filtering (get_filtered_sheet_data): #{e.message}"
    Rails.logger.error "GoogleSheetService: Error filtering: #{e.message}"
    nil
  end

  def get_data(spreadsheet_id, range_name)
    begin
      response = @service.get_spreadsheet_values(spreadsheet_id, range_name)

      if response.values.nil? || response.values.empty?
        puts "Cannot find data in range: #{range_name}"
        return []
      end

      response.values

    rescue Google::Apis::Error => e
      puts "Error when call Google Sheets API (get_data): #{e.message}"
      Rails.logger.error "GoogleSheetService: Error API (get_data): #{e.message}"
      nil
    end
  end

  private

  def get_all_sheet_names(spreadsheet_id)
    begin
      response = @service.get_spreadsheet(spreadsheet_id, fields: "sheets(properties.title)")
      response.sheets.map { |sheet| sheet.properties.title }

    rescue Google::Apis::Error => e
      puts "Error when get sheet names: #{e.message}"
      Rails.logger.error "GoogleSheetService: Error get sheet names: #{e.message}"
      nil
    end
  end

  def authorize
    unless File.exist?(CREDENTIALS_PATH)
      puts "Cannot find credentials file at: #{CREDENTIALS_PATH}"
      puts "Please download the JSON file of the Service Account from Google Cloud Console."
      raise "Missing Google Credentials File"
    end

    Google::Auth::ServiceAccountCredentials.make_creds(
      json_key_io: File.open(CREDENTIALS_PATH),
      scope: SCOPE
    )
  end
end
