# encoding: utf-8
class BugImportService
  attr_reader :errors, :imported_count, :updated_count

  def initialize(task, spreadsheet_id)
    @task = task
    @spreadsheet_id = spreadsheet_id
    @google_service = GoogleSheetService.new
    @errors = []
    @imported_count = 0
    @updated_count = 0
  end

  def import
    Rails.logger.info "Start import bugs from Google Sheet: #{@spreadsheet_id}"
    begin
      gid = extract_gid(@task.bug_link)
      sheets_info = @google_service.get_sheets_info(@spreadsheet_id)

      if sheets_info.nil? || sheets_info.empty?
        @errors << 'Cannot get sheets info from Google Sheet'
        return false
      end

      # Find target sheet(s)
      target_sheets = if gid.present?
                        sheets_info.select { |s| s[:sheet_id] == gid }
                      else
                        # Default to the first sheet if no GID is specified
                        [sheets_info.first]
                      end

      if target_sheets.empty?
        @errors << "Cannot find sheet with gid: #{gid}"
        return false
      end

      target_sheets.each do |sheet|
        sheet_data = @google_service.get_data(@spreadsheet_id, sheet[:title])
        process_sheet(sheet[:title], sheet_data)
      end

      Rails.logger.info "Import bugs complete: #{@imported_count} imported, #{@updated_count} updated"
      true
    rescue StandardError => e
      # Force error message to UTF-8 to avoid clashing with UTF-8 log strings
      error_msg = ensure_utf8(e.message)
      @errors << "Lỗi khi import bug: #{error_msg}"
      Rails.logger.error "BugImportService Error: #{error_msg}\n#{e.backtrace.join("\n")}"
      false
    end
  end

  private

  def process_sheet(sheet_name, sheet_data)
    return if sheet_data.nil? || sheet_data.empty?

    # Based on the screenshot, row 1 is header
    header_row = sheet_data[0]
    column_mapping = parse_header(header_row)

    # Data starts from row 2 (index 1)
    data_rows = sheet_data.drop(1)

    data_rows.each_with_index do |row, index|
      actual_row_number = index + 2
      process_bug_row(row, column_mapping, sheet_name, actual_row_number)
    rescue StandardError => e
      error_msg = ensure_utf8(e.message)
      @errors << "Lỗi dòng #{actual_row_number} trong sheet '#{ensure_utf8(sheet_name)}': #{error_msg}"
      Rails.logger.warn "Bỏ qua dòng #{actual_row_number}: #{error_msg}"
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
      end
    end
    mapping
  end

  def process_bug_row(row, mapping, sheet_name, row_number)
    content = get_cell_value(row, mapping[:content])
    return if content.blank?

    # Since Bug model has 'title', we'll use first line of content as title
    title = content.split("\n").first.truncate(200)

    # Always use current task (parent task) as requested by user
    bug = @task.bugs.find_or_initialize_by(title: title)

    dev_name = get_cell_value(row, mapping[:dev])
    test_name = get_cell_value(row, mapping[:test])

    dev = find_user(dev_name)
    tester = find_user(test_name)

    bug.assign_attributes(
      content: content,
      application: normalize_application(get_cell_value(row, mapping[:application])),
      category: normalize_category(get_cell_value(row, mapping[:category])),
      priority: normalize_priority(get_cell_value(row, mapping[:priority])),
      status: normalize_status(get_cell_value(row, mapping[:status])),
      image_video_url: get_cell_value(row, mapping[:media]),
      dev_id: dev&.id,
      tester_id: tester&.id,
      dev_name_raw: dev_name,
      tester_name_raw: test_name
    )

    if bug.new_record?
      @imported_count += 1 if bug.save
    else
      @updated_count += 1 if bug.save
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
    User.where("name LIKE ?", "%#{name}%").first
  end

  def normalize_application(app)
    return 'sp_pc' if app.blank?
    case app.downcase.gsub(' ', '')
    when /sp\+pc/ then 'sp_pc'
    when /app/ then 'app'
    when /sp/ then 'sp'
    when /pc/ then 'pc'
    when /all/ then 'all'
    else 'sp_pc'
    end
  end

  def normalize_category(cat)
    return 'stg_vn' if cat.blank?
    case cat.downcase
    when /stg.*vn/ then 'stg_vn'
    when /stg.*jp/ then 'stg_jp'
    when /prod/ then 'prod'
    when /requirement/ then 'new_requirement'
    else 'stg_vn'
    end
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
    when /done/, /đã.*xong/, /ok/ then 'done'
    when /fixing/, /đang.*sửa/ then 'fixing'
    when /testing/, /đang.*test/ then 'testing'
    when /pending/, /chờ/ then 'pending'
    else 'new'
    end
  end

  def ensure_utf8(str)
    str = str.to_s
    str = str.dup if str.frozen?
    str.force_encoding('UTF-8').scrub
  end
end
