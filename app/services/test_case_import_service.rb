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
        @errors << "Cannot get data from Google Sheet"
        return false
      end

      all_sheet_data.each do |sheet_name, sheet_data|
        process_sheet(sheet_name, sheet_data)
      end

      Rails.logger.info "Import hoàn tất: #{@imported_count} test cases, bỏ qua: #{@skipped_count}"
      true
    rescue => e
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

    # Row 5 might contain device names (check if it's not a test case row)
    device_names_row = sheet_data[4] if sheet_data.length > 4

    # Check if Row 5 is a data row or device names row
    row_5_is_data = is_data_row?(device_names_row, header_rows.last)

    # Determine how many rows to skip
    if row_5_is_data
      # Row 5 is TC01 (first test case) - only skip 4 header rows
      data_rows = sheet_data.drop(4)
      starting_row_number = 5
      device_names_row = nil # Don't use row 5 as device names
      Rails.logger.info "Row 5 is data row (TC01) - starting from row 5"
    else
      # Row 5 is device names - skip 5 rows
      data_rows = sheet_data.drop(5)
      starting_row_number = 6
      Rails.logger.info "Row 5 is device names row - starting from row 6"
    end

    # Parse header to get column positions and device names
    column_mapping = parse_header(header_rows, device_names_row)

    # Process each data row
    data_rows.each_with_index do |row, index|
      begin
        actual_row_number = starting_row_number + index
        process_test_case_row(row, column_mapping, sheet_name, actual_row_number)
      rescue => e
        actual_row_number = starting_row_number + index
        @errors << "Lỗi dòng #{actual_row_number} trong sheet '#{sheet_name}': #{e.message}"
        @skipped_count += 1
        Rails.logger.warn "Bỏ qua dòng #{actual_row_number}: #{e.message}"
      end
    end
  end

  # Check if a row is a data row (contains test case data) or device names row
  def is_data_row?(row, header_row)
    return false if row.nil? || row.empty?
    return false if header_row.nil?

    # Find the Target column index
    target_col_index = nil
    header_row.each_with_index do |col_name, index|
      next if col_name.nil? || col_name.strip.empty?
      normalized_name = col_name.strip.downcase
      if normalized_name.match?(/^target$|^対象$|^đối.*tượng$/)
        target_col_index = index
        break
      end
    end

    return false if target_col_index.nil?

    # Check if row contains test status values in columns after Target
    # If yes, it's a data row (test case row)
    # If no, it's a device names row
    ((target_col_index + 1)...header_row.length).each do |col_idx|
      val = row[col_idx]
      next if val.nil?

      val_normalized = val.to_s.strip.downcase
      # Check if value is a test status (Pass/Fail/OK/NG/etc.)
      if val_normalized.match?(/^(pass|fail|failed|ok|ng|not.*run|skip|pending|block|blocked)$/i)
        Rails.logger.info "Row 5 contains test status '#{val}' at column #{col_idx} - treating as data row"
        return true
      end

      # Check if value looks like a test case ID (TC01, TC02, etc.)
      if val_normalized.match?(/^tc\d+$/i)
        Rails.logger.info "Row 5 contains test case ID '#{val}' - treating as data row"
        return true
      end
    end

    # Also check first few columns for test case identifiers
    # Column 0-3 usually contain: ID, Type, Function, Test Case
    row.first(4).each_with_index do |val, idx|
      next if val.nil?
      val_normalized = val.to_s.strip.downcase

      # If any of first 4 columns contain TC ID pattern, it's likely a data row
      if val_normalized.match?(/^tc\d+$/i) || val_normalized.match?(/^\d+$/)
        Rails.logger.info "Row 5 column #{idx} contains identifier '#{val}' - treating as data row"
        return true
      end
    end

    Rails.logger.info "Row 5 does not contain test data markers - treating as device names row"
    false
  end

  def parse_header(header_rows, device_names_row = nil)
    # Assume the structure of Google Sheet is as follows:
    # Row 1-3: Metadata (Created by, Executed by, etc.)
    # Row 4: Column headers
    # Row 5: Device names (optional - only for device columns)

    header_row = header_rows.last || []

    mapping = {}
    device_columns = [] # Track device/environment columns
    found_target_col = false
    target_col_index = nil

    header_row.each_with_index do |col_name, index|
      next if col_name.nil? || col_name.strip.empty?

      normalized_name = col_name.strip.downcase

      # Map các tên cột phổ biến
      case normalized_name
      when /^id$/, /^no$/, /^stt$/, /^順番$/
        mapping[:id] = index
      when /^type$/, /^test.*type$/, /^種別$/
        mapping[:test_type] = index
      when /^function$/, /^funtion$/, /^機能$/, /^chức.*năng$/ # Note: "Funtion" typo in some sheets
        mapping[:function] = index
      when /^test.*case$/, /^test.*item$/, /^項目$/, /^test.*nội.*dung$/
        mapping[:test_case] = index
      when /^action$/, /^操作$/, /^thao.*tác$/, /^step$/, /^test.*step/
        mapping[:action] = index
      when /^expected.*result$/, /^期待.*結果$/, /^kết.*quả.*mong.*đợi$/, /^result$/
        mapping[:expected_result] = index
      when /^target$/, /^対象$/, /^đối.*tượng$/
        mapping[:target] = index
        found_target_col = true
        target_col_index = index
      when /^ac$/, /^acceptance.*criteria$/, /^受入.*基準$/
        mapping[:acceptance_criteria] = index
      when /^us$/, /^user.*story$/, /^ユーザー.*ストーリー$/
        mapping[:user_story] = index
      when /^note$/,  /^備考$/, /^ghi.*chú$/
        # Note column marks the end - stop here
        break
      when /browser.*device.*os/
        # Generic label - check device_names_row for actual device names
        # Don't break, continue to find actual names
      when /chrome/, /firefox/, /safari/, /edge/, /android/, /ios/, /iphone/, /ipad/, /^prod$/i, /^stg/i, /environment/, /version/, /deploy.*gate/, /testflight/
        # Specific browser/device names in header - SAVE
        device_columns << { index: index, name: col_name.strip }
      end
    end

    # Check device_names_row (Row 5) for device names in columns after Target
    # BUT: Only if Row 5 contains actual device names, not test status values
    if device_names_row && target_col_index
      # Check if Row 5 contains device names or test results
      # If it contains test status values (Pass/Failed/Not Run), skip it
      has_test_status = false
      ((target_col_index + 1)...header_row.length).each do |col_idx|
        val = device_names_row[col_idx]
        if val && val.strip.match?(/^(pass|fail|failed|ok|ng|not.*run|skip|pending|block|blocked)$/i)
          has_test_status = true
          break
        end
      end

      # Only parse Row 5 if it doesn't contain test status (means it has device names)
      unless has_test_status
        # Scan columns after Target column
        ((target_col_index + 1)...header_row.length).each do |col_idx|
          device_name = device_names_row[col_idx]

          # Stop if we hit Note column
          header_name = header_row[col_idx]
          break if header_name && header_name.match?(/^note$/i)

          if device_name && !device_name.strip.empty?
            # Found device name in Row 5
            device_columns << { index: col_idx, name: device_name.strip }
          end
        end
      end
    end

    # Remove duplicates by index (keep first occurrence)
    device_columns = device_columns.uniq { |col| col[:index] }

    # Store device columns separately
    mapping[:device_columns] = device_columns unless device_columns.empty?

    Rails.logger.info "Parsed device columns from rows 4-5: #{device_columns.inspect}"

    mapping
  end

  def process_test_case_row(row, column_mapping, sheet_name, row_number)
    # Get data from row according to mapping
    test_id = get_cell_value(row, column_mapping[:id])
    test_type = get_cell_value(row, column_mapping[:test_type])
    function = get_cell_value(row, column_mapping[:function])
    test_case_title = get_cell_value(row, column_mapping[:test_case])
    action = get_cell_value(row, column_mapping[:action])
    expected_result = get_cell_value(row, column_mapping[:expected_result])
    target = get_cell_value(row, column_mapping[:target])
    ac_url = get_cell_value(row, column_mapping[:acceptance_criteria])
    us_url = get_cell_value(row, column_mapping[:user_story])

    # Parse device/environment test results
    device_results = parse_device_results(row, column_mapping[:device_columns])

    # If there is no test_case_title, create from ID or Function
    if test_case_title.blank?
      if test_id.present? && function.present?
        # Truncate function if it's too long
        function_short = function.length > 100 ? "#{function[0..97]}..." : function
        test_case_title = "#{test_id} - #{function_short}"
      elsif test_id.present?
        test_case_title = test_id
      elsif function.present?
        test_case_title = function
      else
        Rails.logger.warn "Bỏ qua dòng #{row_number}: Không có tiêu đề test case"
        @skipped_count += 1
        return
      end
    end

    # Normalize test_type
    normalized_test_type = normalize_test_type(test_type)
    normalized_target = normalize_target(target)

    # Create or find test case (based on title because title is unique)
    test_case = @task.test_cases.find_or_initialize_by(
      title: test_case_title
    )

    test_case.assign_attributes(
      test_type: normalized_test_type,
      function: function,
      target: normalized_target,
      description: "Imported from sheet: #{sheet_name}, row: #{row_number}",
      acceptance_criteria_url: ac_url,
      user_story_url: us_url
    )

    if test_case.save
      # Create test step with action and expected result
      create_test_step(test_case, action, expected_result)

      # Create test_result records for each device
      create_device_test_results(test_case, device_results)

      @imported_count += 1
    else
      @errors << "Không thể lưu test case dòng #{row_number}: #{test_case.errors.full_messages.join(', ')}"
      @skipped_count += 1
    end
  end

  def create_test_step(test_case, action, expected_result)
    # Count current steps to create new step_number
    step_number = test_case.test_steps.count + 1

    test_step = test_case.test_steps.create!(
      step_number: step_number,
      description: "Step #{step_number}"
    )

    # Create content for action
    if action.present?
      action_lines = action.split("\n").reject(&:blank?)
      action_lines.each_with_index do |line, index|
        test_step.test_step_contents.create!(
          content_type: "text",
          content_value: line.strip,
          content_category: "action",
          display_order: index
        )
      end
    end

    # Create content for expected result
    if expected_result.present?
      expected_lines = expected_result.split("\n").reject(&:blank?)
      expected_lines.each_with_index do |line, index|
        test_step.test_step_contents.create!(
          content_type: "text",
          content_value: line.strip,
          content_category: "expectation",
          display_order: index
        )
      end
    end
  end

  def create_device_test_results(test_case, device_results)
    return if device_results.blank?

    device_results.each do |result|
      # Delete old test_result for this device if any
      test_case.test_results.where(device: result[:device]).destroy_all

      # Create new test_result
      test_case.test_results.create!(
        device: result[:device],
        status: result[:status],
        run_id: nil, # Import doesn't have run_id
        executed_at: Time.current
      )
    end
  end

  def get_cell_value(row, column_index)
    return nil if column_index.nil?
    return nil if row.nil? || row[column_index].nil?
    row[column_index].to_s.strip
  end

  def normalize_test_type(test_type)
    return "feature" if test_type.blank?

    normalized = test_type.strip.downcase
    case normalized
    when "ui", "ユーザーインターフェース", "giao diện"
      "ui"
    when "feature", "機能", "chức năng", "data", "dữ liệu"
      "feature"
    else
      "feature"
    end
  end

  def normalize_target(target)
    return "pc_sp_app" if target.blank?

    normalized = target.strip.downcase.gsub(/[・、\s]/, "_")
    case normalized
    when /pc.*sp.*app/, /pc_sp_app/
      "pc_sp_app"
    when /pc.*sp/, /pc_sp/
      "pc_sp"
    when /^app$/
      "app"
    when /^pc$/
      "pc"
    when /^sp$/
      "sp"
    else
      "pc_sp_app"
    end
  end

  def parse_device_results(row, device_columns)
    return [] if device_columns.nil? || device_columns.empty?

    results = []
    device_columns.each do |device_col|
      device_name = device_col[:name]
      result_value = get_cell_value(row, device_col[:index])

      next if result_value.blank?

      # Normalize status
      status = normalize_test_status(result_value)

      results << {
        device: device_name,
        status: status,
        raw_value: result_value
      }
    end

    results
  end

  def normalize_test_status(status_value)
    return "not_run" if status_value.blank?

    normalized = status_value.strip.downcase
    case normalized
    when /pass/, /ok/, /success/, /成功/
      "pass"
    when /fail/, /error/, /ng/, /失敗/
      "fail"
    when /not.*run/, /未実施/, /skip/, /pending/
      "not_run"
    when /block/, /blocked/, /ブロック/
      "blocked"
    else
      "unknown"
    end
  end
end
