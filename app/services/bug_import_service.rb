class BugImportService
  attr_reader :errors, :imported_count, :updated_count

  def initialize(task, spreadsheet_id, wipe_existing: false)
    @task = task
    @spreadsheet_id = spreadsheet_id
    @wipe_existing = wipe_existing
    @google_service = GoogleSheetService.new
    @errors = []
    @imported_count = 0
    @updated_count = 0
  end

  def import
    Rails.logger.info "Start import bugs from Google Sheet: #{@spreadsheet_id}"
    begin
      target_sheets = find_target_sheets
      return false unless target_sheets

      wipe_existing_bugs if @wipe_existing && @errors.empty?

      target_sheets.each do |sheet|
        sheet_data = @google_service.get_data(@spreadsheet_id, sheet[:title])
        process_sheet(sheet[:title], sheet_data)
      end

      Rails.logger.info "Import bugs complete: #{@imported_count} imported, #{@updated_count} updated"
      true
    rescue StandardError => e
      add_import_error(e)
      false
    end
  end

  private

  def wipe_existing_bugs
    Rails.logger.info "Wiping existing bugs for task #{@task.id}"
    @task.bugs.destroy_all
    @imported_count = 0
    @updated_count = 0
  end

  def find_target_sheets
    gid = extract_gid(@task.bug_link)
    sheets_info = @google_service.get_sheets_info(@spreadsheet_id)

    if sheets_info.nil? || sheets_info.empty?
      @errors << 'Cannot get sheets info from Google Sheet'
      return nil
    end

    target_sheets = gid.present? ? sheets_info.select { |s| s[:sheet_id] == gid } : [sheets_info.first]

    if target_sheets.empty?
      @errors << "Cannot find sheet with gid: #{gid}"
      return nil
    end

    target_sheets
  end

  def add_import_error(exception)
    error_msg = ensure_utf8(exception.message)
    @errors << "Error importing bug: #{error_msg}"
    Rails.logger.error "BugImportService Error: #{error_msg}\n#{exception.backtrace.join("\n")}"
  end

  def process_sheet(sheet_name, sheet_data)
    return if sheet_data.nil? || sheet_data.empty?

    # Based on the screenshot, row 1 is header
    header_row = sheet_data[0]
    column_mapping = parse_header(header_row)

    # Data starts from row 2 (index 1)
    data_rows = sheet_data.drop(1)

    data_rows.each_with_index do |row, index|
      actual_row_number = index + 2
      process_bug_row(row, column_mapping)
    rescue StandardError => e
      error_msg = ensure_utf8(e.message)
      @errors << "Error at row #{actual_row_number} in sheet '#{ensure_utf8(sheet_name)}': #{error_msg}"
      Rails.logger.warn "Skipping row #{actual_row_number}: #{error_msg}"
    end
  end

  def parse_header(header_row)
    mapping = {}
    header_row.each_with_index do |col_name, index|
      next if col_name.blank?

      name = ensure_utf8(col_name).downcase
      case name
      when /^no$/, /^stt$/ then mapping[:no] = index
      when /^content$/, /^mô tả$/, /^bug content$/ then mapping[:content] = index
      when /^application$/, /^app$/ then mapping[:application] = index
      when /^category/, /^loại/, /^biến thể$/ then mapping[:category] = index
      when /^priority$/, /^mức độ ưu tiên$/, /^độ ưu tiên$/ then mapping[:priority] = index
      when /^dev$/ then mapping[:dev] = index
      when /^test$/, /^tester$/ then mapping[:test] = index
      when /^status$/, /^trạng thái$/ then mapping[:status] = index
      when /^image/, /^video/, /^gyazo/, /^link.*ảnh/ then mapping[:media] = index
      when /^bug.?type$/, /^loại.?bug$/ then mapping[:bug_type] = index
      end
    end
    mapping
  end

  def process_bug_row(row, mapping)
    content = get_cell_value(row, mapping[:content])
    return if content.blank?

    title = content.split("\n").first.truncate(200)
    bug = @task.bugs.find_or_initialize_by(title: title)

    assign_bug_attributes(bug, row, mapping)
    save_bug(bug)
  end

  def assign_bug_attributes(bug, row, mapping)
    dev_name = get_cell_value(row, mapping[:dev])
    test_name = get_cell_value(row, mapping[:test])

    bug.assign_attributes(
      content: get_cell_value(row, mapping[:content]),
      application: normalize_application(get_cell_value(row, mapping[:application])),
      category: normalize_category(get_cell_value(row, mapping[:category])),
      priority: normalize_priority(get_cell_value(row, mapping[:priority])),
      status: normalize_status(get_cell_value(row, mapping[:status])),
      bug_type: normalize_bug_type(get_cell_value(row, mapping[:bug_type])),
      image_video_url: get_cell_value(row, mapping[:media]),
      dev_id: find_user(dev_name)&.id,
      tester_id: find_user(test_name)&.id,
      dev_name_raw: dev_name,
      tester_name_raw: test_name
    )
  end

  def save_bug(bug)
    if bug.new_record?
      @imported_count += 1 if bug.save
    elsif bug.save
      @updated_count += 1
    end
  end

  def extract_gid(url)
    return nil if url.blank?

    # Extract gid from query params (e.g., ?gid=123) or fragment (e.g., #gid=123)
    # This regex looks for gid= followed by digits
    match = url.match(/[?&#]gid=([0-9]+)/)
    match[1] if match
  end

  def get_cell_value(row, index)
    return nil if index.nil? || row[index].nil?

    ensure_utf8(row[index].to_s).strip
  end

  def find_user(name)
    return nil if name.blank?

    # Simple fuzzy search for user name
    User.where('name LIKE ?', "%#{name}%").first
  end

  def normalize_application(app)
    return 'sp_pc' if app.blank?

    normalized = app.downcase.gsub(' ', '')
    return 'app' if normalized.match?(/app/)
    return 'sp' if normalized.match?(/sp/) && !normalized.match?(/sp\+pc/)
    return 'pc' if normalized.match?(/pc/) && !normalized.match?(/sp\+pc/)

    'sp_pc'
  end

  def normalize_category(cat)
    return 'stg_vn' if cat.blank?

    normalized = cat.downcase
    return 'stg_jp' if normalized.match?(/stg.*jp/)
    return 'prod' if normalized.match?(/prod/)

    'stg_vn'
  end

  def normalize_priority(pri)
    return 'normal' if pri.blank?

    case pri.downcase
    when /high/, /cao/ then 'high'
    when /low/, /thấp/ then 'low'
    else 'normal'
    end
  end

  def normalize_status(stat)
    return 'new' if stat.blank?

    case stat.downcase
    when /done/, /completed/, /ok/ then 'done'
    when /fixing/, /in progress/ then 'fixing'
    when /testing/ then 'testing'
    when /pending/, /chờ/ then 'pending'
    else 'new'
    end
  end

  def normalize_bug_type(bt)
    return 'new_bug' if bt.blank?

    case bt.downcase
    when /new/, /mới/ then 'new_bug'
    when /old/, /cũ/ then 'old_bug'
    when /improve/, /cải tiến/ then 'improve'
    else 'new_bug'
    end
  end

  def ensure_utf8(str)
    str = str.to_s
    str = str.dup if str.frozen?
    str.force_encoding('UTF-8').scrub
  end
end
