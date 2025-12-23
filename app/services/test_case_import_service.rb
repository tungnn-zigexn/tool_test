class TestCaseImportService
  attr_reader :errors, :imported_count, :skipped_count

  def initialize(task, spreadsheet_id)
    @task = task
    @spreadsheet_id = spreadsheet_id
    @google_service = GoogleSheetService.new
    @errors = []
    @imported_count = 0
    @skipped_count = 0
  end

  # Import test cases from Google Sheet
  def import
    Rails.logger.info "Start import test cases from Google Sheet: #{@spreadsheet_id}"

    begin
      all_sheet_data = @google_service.get_project_test_cases(@spreadsheet_id)

      if all_sheet_data.nil? || all_sheet_data.empty?
        @errors << 'Cannot get data from Google Sheet'
        return false
      end

      all_sheet_data.each do |sheet_name, sheet_data|
        process_sheet(sheet_name, sheet_data)
      end

      Rails.logger.info "Import hoàn tất: #{@imported_count} test cases, bỏ qua: #{@skipped_count}"
      true
    rescue StandardError => e
      @errors << "Lỗi khi import: #{e.message}"
      Rails.logger.error "TestCaseImportService Error: #{e.message}\n#{e.backtrace.join("\n")}"
      false
    end
  end

  # Public method to import from sheet data directly (for multi-sheet service)
  def import_from_sheet_data(sheet_name, sheet_data)
    process_sheet(sheet_name, sheet_data)
  end

  private

  def process_sheet(sheet_name, sheet_data)
    return if sheet_data.nil? || sheet_data.empty?

    Rails.logger.info "Processing sheet: #{sheet_name} with #{sheet_data.length} rows"

    # Skip 4 header rows
    header_rows = sheet_data.first(4)
    device_names_row = sheet_data[4] if sheet_data.length > 4

    # Check if Row 5 is a data row or device names row
    row_5_is_data = data_row?(device_names_row, header_rows.last)

    # Determine how many rows to skip
    if row_5_is_data
      data_rows = sheet_data.drop(4)
      starting_row_number = 5
      device_names_row = nil
      Rails.logger.info 'Row 5 is data row (TC01) - starting from row 5'
    else
      data_rows = sheet_data.drop(5)
      starting_row_number = 6
      Rails.logger.info 'Row 5 is device names row - starting from row 6'
    end

    process_data_rows(data_rows, header_rows, device_names_row, sheet_name, starting_row_number)
  end

  def process_data_rows(data_rows, header_rows, device_names_row, sheet_name, starting_row_number)
    column_mapping = parse_header(header_rows, device_names_row)

    data_rows.each_with_index do |row, index|
      actual_row_number = starting_row_number + index
      process_test_case_row(row, column_mapping, sheet_name, actual_row_number)
    rescue StandardError => e
      @errors << "Lỗi dòng #{actual_row_number} trong sheet '#{sheet_name}': #{e.message}"
      @skipped_count += 1
      Rails.logger.warn "Bỏ qua dòng #{actual_row_number}: #{e.message}"
    end
  end

  # Check if a row is a data row (contains test case data) or device names row
  def data_row?(row, header_row)
    return false if row.nil? || row.empty? || header_row.nil?

    target_col_index = find_target_column_index(header_row)
    return false if target_col_index.nil?

    # Check if row contains test status values or TC ID pattern
    row_contains_status?(row, target_col_index, header_row.length) ||
      row_contains_identifier?(row)
  end

  def find_target_column_index(header_row)
    header_row.each_with_index do |col_name, index|
      next if col_name.blank?

      return index if col_name.strip.downcase.match?(/^target$|^対象$|^đối.*tượng$/)
    end
    nil
  end

  def row_contains_status?(row, target_idx, row_len)
    ((target_idx + 1)...row_len).any? do |idx|
      val = row[idx].to_s.strip.downcase
      val.match?(/^(pass|fail|failed|ok|ng|not.*run|skip|pending|block|blocked)$/i) || val.match?(/^tc\d+$/i)
    end
  end

  def row_contains_identifier?(row)
    row.first(4).any? do |val|
      val_norm = val.to_s.strip.downcase
      val_norm.match?(/^tc\d+$/i) || val_norm.match?(/^\d+$/)
    end
  end

  def parse_header(header_rows, device_names_row = nil)
    header_row = header_rows.last || []
    mapping = {}
    device_columns = []

    header_row.each_with_index do |col_name, index|
      next if col_name.blank?
      break if col_name.strip.downcase.match?(/^note$|^備考$|^ghi.*chú$/)

      map_column_header(col_name, index, mapping, device_columns)
    end

    if device_names_row && mapping[:target]
      add_device_row_columns(header_row, device_names_row, mapping[:target], device_columns)
    end

    finalize_mapping(mapping, device_columns)
  end

  def map_column_header(col_name, index, mapping, device_columns)
    name = col_name.strip.downcase

    case name
    when /^id$/, /^no$/, /^stt$/, /^順番$/ then mapping[:id] = index
    when /^type$/, /^test.*type$/, /^種別$/ then mapping[:test_type] = index
    when /^function$/, /^funtion$/, /^機能$/, /^chức.*năng$/ then mapping[:function] = index
    when /^test.*case$/, /^test.*item$/, /^項目$/, /^test.*nội.*dung$/ then mapping[:test_case] = index
    when /^action$/, /^操作$/, /^thao.*tác$/, /^step$/, /^test.*step/ then mapping[:action] = index
    when /^expected.*result$/, /^期待.*結果$/, /^kết.*quả.*mong.*đợi$/, /^result$/ then mapping[:expected_result] = index
    when /^target$/, /^対象$/, /^đối.*tượng$/ then mapping[:target] = index
    when /^ac$/, /^acceptance.*criteria$/, /^受入.*基準$/ then mapping[:acceptance_criteria] = index
    when /^us$/, /^user.*story$/, /^ユーザー.*ストーリー$/ then mapping[:user_story] = index
    when /chrome|firefox|safari|edge|android|ios|iphone|ipad/,
         /^prod$/i, /^stg/i, /environment|version|deploy.*gate|testflight/
      device_columns << { index: index, name: col_name.strip }
    end
  end

  def add_device_row_columns(header_row, device_row, target_idx, device_columns)
    return if row_contains_status?(device_row, target_idx, header_row.length)

    ((target_idx + 1)...header_row.length).each do |idx|
      header_name = header_row[idx]
      break if header_name&.match?(/^note$/i)

      device_name = device_row[idx]
      device_columns << { index: idx, name: device_name.strip } if device_name.present?
    end
  end

  def finalize_mapping(mapping, device_columns)
    mapping[:device_columns] = device_columns.uniq { |col| col[:index] }
    Rails.logger.info "Parsed device columns: #{mapping[:device_columns].inspect}"
    mapping
  end

  def process_test_case_row(row, mapping, sheet_name, row_number)
    case_data = extract_case_data(row, mapping)
    device_results = parse_device_results(row, mapping[:device_columns])

    title = case_data[:test_case_title]
    if title.blank?
      title = build_test_case_title(case_data[:test_id], case_data[:function])
      return skip_row(row_number) if title.blank?
    end

    test_case = @task.test_cases.find_or_initialize_by(title: title)
    test_case.assign_attributes(test_case_import_attributes(case_data, sheet_name, row_number))

    if test_case.save
      create_test_step(test_case, case_data[:action], case_data[:expected_result])
      create_device_test_results(test_case, device_results)
      @imported_count += 1
    else
      handle_test_case_save_error(test_case, row_number)
    end
  end

  def extract_case_data(row, mapping)
    {
      test_id: get_cell_value(row, mapping[:id]),
      test_type: get_cell_value(row, mapping[:test_type]),
      function: get_cell_value(row, mapping[:function]),
      test_case_title: get_cell_value(row, mapping[:test_case]),
      action: get_cell_value(row, mapping[:action]),
      expected_result: get_cell_value(row, mapping[:expected_result]),
      target: get_cell_value(row, mapping[:target]),
      ac_url: get_cell_value(row, mapping[:acceptance_criteria]),
      us_url: get_cell_value(row, mapping[:user_story])
    }
  end

  def build_test_case_title(test_id, function)
    if test_id.present? && function.present?
      function_short = function.length > 100 ? "#{function[0..97]}..." : function
      "#{test_id} - #{function_short}"
    elsif test_id.present?
      test_id
    elsif function.present?
      function
    end
  end

  def skip_row(row_number)
    Rails.logger.warn "Bỏ qua dòng #{row_number}: Không có tiêu đề test case"
    @skipped_count += 1
  end

  def test_case_import_attributes(case_data, sheet_name, row_number)
    {
      test_type: normalize_test_type(case_data[:test_type]),
      function: case_data[:function],
      target: normalize_target(case_data[:target]),
      description: "Imported from sheet: #{sheet_name}, row: #{row_number}",
      acceptance_criteria_url: case_data[:ac_url],
      user_story_url: case_data[:us_url]
    }
  end

  def handle_test_case_save_error(test_case, row_number)
    @errors << "Không thể lưu test case dòng #{row_number}: #{test_case.errors.full_messages.join(', ')}"
    @skipped_count += 1
  end

  def create_test_step(test_case, action, expected_result)
    step_number = test_case.test_steps.count + 1
    test_step = test_case.test_steps.create!(
      step_number: step_number,
      description: "Step #{step_number}"
    )

    create_step_contents(test_step, action, 'action') if action.present?
    create_step_contents(test_step, expected_result, 'expectation') if expected_result.present?
  end

  def create_step_contents(test_step, content, category)
    lines = content.split("\n").reject(&:blank?)
    lines.each_with_index do |line, index|
      test_step.test_step_contents.create!(
        content_type: 'text',
        content_value: line.strip,
        content_category: category,
        display_order: index
      )
    end
  end

  def create_device_test_results(test_case, device_results)
    return if device_results.blank?

    device_results.each do |result|
      test_case.test_results.where(device: result[:device]).destroy_all
      test_case.test_results.create!(
        device: result[:device], status: result[:status],
        run_id: nil, executed_at: Time.current
      )
    end
  end

  def get_cell_value(row, column_index)
    return nil if column_index.nil? || row.nil? || row[column_index].nil?

    row[column_index].to_s.strip
  end

  def normalize_test_type(test_type)
    return 'feature' if test_type.blank?

    case test_type.strip.downcase
    when 'ui', 'ユーザーインターフェース', 'giao diện' then 'ui'
    else 'feature'
    end
  end

  def normalize_target(target)
    return 'pc_sp_app' if target.blank?

    normalized = target.strip.downcase.gsub(/[・、\s]/, '_')
    if normalized.include?('pc') && normalized.include?('sp')
      normalized.include?('app') ? 'pc_sp_app' : 'pc_sp'
    elsif %w[app pc sp].include?(normalized)
      normalized
    else
      'pc_sp_app'
    end
  end

  def parse_device_results(row, device_columns)
    return [] if device_columns.blank?

    device_columns.each_with_object([]) do |device_col, results|
      value = get_cell_value(row, device_col[:index])
      next if value.blank?

      results << {
        device: device_col[:name],
        status: normalize_test_status(value),
        raw_value: value
      }
    end
  end

  def normalize_test_status(status_value)
    return 'not_run' if status_value.blank?

    case status_value.strip.downcase
    when /pass/, /ok/, /success/, /成功/ then 'pass'
    when /fail/, /error/, /ng/, /失敗/ then 'fail'
    when /not.*run/, /未実施/, /skip/, /pending/ then 'not_run'
    when /block/, /blocked/, /ブロック/ then 'blocked'
    else 'unknown'
    end
  end
end
