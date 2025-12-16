# Service to import task from Redmine with multi-sheet support
# Each sheet in Google Sheet will create a separate subtask
class RedmineMultiSheetImportService
  attr_reader :errors, :parent_task, :subtasks, :project

  def initialize(redmine_id, project_id)
    @redmine_id = redmine_id
    @project = Project.find(project_id)
    @errors = []
    @parent_task = nil
    @subtasks = []
    @google_service = GoogleSheetService.new
  end

  # Import task from Redmine with multi-sheet support
  def import
    Rails.logger.info "Start import multi-sheet task from Redmine: #{@redmine_id}"

    begin
      # Get issue from Redmine
      issue_data = fetch_issue_from_redmine
      return false if issue_data.nil?

      # Create or update parent task
      create_or_update_parent_task(issue_data)

      # Check if there is testcase link
      unless @parent_task.testcase_link.present?
        Rails.logger.warn 'Cannot find testcase link, only import parent task'
        return true
      end

      # Get spreadsheet ID from link
      spreadsheet_id = extract_spreadsheet_id(@parent_task.testcase_link)

      # Get all sheet names from Google Sheet
      all_sheet_data = @google_service.get_project_test_cases(spreadsheet_id)

      if all_sheet_data.nil? || all_sheet_data.empty?
        @errors << 'Cannot get data from Google Sheet'
        return false
      end

      # For each sheet, create a subtask and import test cases
      all_sheet_data.each do |sheet_name, sheet_data|
        create_subtask_with_test_cases(sheet_name, sheet_data)
      end

      # Update total number of test cases for parent task
      update_parent_task_stats

      Rails.logger.info "Import multi-sheet successfully: #{@parent_task.title}"
      Rails.logger.info "Created #{@subtasks.length} subtasks"
      true
    rescue StandardError => e
      @errors << "Error when import task: #{e.message}"
      Rails.logger.error "RedmineMultiSheetImportService Error: #{e.message}\n#{e.backtrace.join("\n")}"
      false
    end
  end

  private

  def fetch_issue_from_redmine
    issue_data = if @redmine_id.to_s.match?(/^\d+$/)
                   RedmineService.get_issues(@redmine_id)
                 else
                   @errors << 'Vui lòng truyền vào issue ID (số) thay vì tên'
                   return nil
                 end

    if issue_data.nil?
      @errors << "Không tìm thấy issue từ Redmine với ID: #{@redmine_id}"
      return nil
    end

    issue_data
  end

  def create_or_update_parent_task(issue_data)
    title = issue_data['subject']
    custom_fields = parse_custom_fields(issue_data['custom_fields'] || [])

    @parent_task = @project.tasks.find_or_initialize_by(
      redmine_id: @redmine_id
    )

    @parent_task.assign_attributes(
      title: title,
      parent_id: issue_data.dig('parent', 'id'),
      description: issue_data['description'],
      status: issue_data.dig('status', 'name'),
      estimated_time: parse_hours(issue_data['estimated_hours']),
      spent_time: parse_hours(issue_data['spent_hours']),
      percent_done: issue_data['done_ratio'],
      start_date: issue_data['start_date'],
      due_date: issue_data['due_date'],
      testcase_link: custom_fields['testcase_link'],
      bug_link: custom_fields['bug_link'],
      stg_bugs_vn: custom_fields['stg_bugs_vn'],
      stg_bugs_jp: custom_fields['stg_bugs_jp'],
      prod_bugs: custom_fields['production_bugs'],
      created_by_name: issue_data.dig('assigned_to', 'name')
    )

    unless @parent_task.save
      @errors << "Không thể lưu parent task: #{@parent_task.errors.full_messages.join(', ')}"
      raise 'Cannot save parent task'
    end

    @parent_task
  end

  def create_subtask_with_test_cases(sheet_name, sheet_data)
    Rails.logger.info "Tạo subtask cho sheet: #{sheet_name}"

    # Create subtask from sheet name
    subtask = @parent_task.subtasks.find_or_initialize_by(
      title: "#{@parent_task.title} - #{sheet_name}"
    )

    subtask.assign_attributes(
      project_id: @project.id,
      description: "Subtask tự động tạo từ sheet: #{sheet_name}",
      status: @parent_task.status,
      start_date: @parent_task.start_date,
      due_date: @parent_task.due_date,
      created_by_name: @parent_task.created_by_name
    )

    if subtask.save
      @subtasks << subtask

      # Import test cases for this subtask
      import_service = TestCaseImportService.new(subtask, nil)

      # Process sheet data directly using public method
      import_service.import_from_sheet_data(sheet_name, sheet_data)

      # Update number of test cases for subtask
      subtask.update(number_of_test_cases: import_service.imported_count)

      Rails.logger.info "Subtask '#{subtask.title}' tạo thành công với #{import_service.imported_count} test cases"

      # Log errors if any
      if import_service.errors.any?
        @errors.concat(import_service.errors)
        Rails.logger.warn "Import test cases có lỗi: #{import_service.errors.join(', ')}"
      end
    else
      @errors << "Không thể tạo subtask cho sheet '#{sheet_name}': #{subtask.errors.full_messages.join(', ')}"
      Rails.logger.error "Lỗi tạo subtask: #{subtask.errors.full_messages.join(', ')}"
    end
  rescue StandardError => e
    @errors << "Lỗi khi xử lý sheet '#{sheet_name}': #{e.message}"
    Rails.logger.error "Lỗi xử lý sheet #{sheet_name}: #{e.message}\n#{e.backtrace.join("\n")}"
  end

  def update_parent_task_stats
    # Calculate total number of test cases from all subtasks
    total_test_cases = @subtasks.sum(&:number_of_test_cases)
    @parent_task.update(number_of_test_cases: total_test_cases)
  end

  def parse_custom_fields(custom_fields)
    result = {}

    custom_fields.each do |field|
      name = field['name'].to_s.downcase.strip.gsub(/ +/, '_').gsub(/[()]/, '')
      value = field['value']
      result[name] = value
    end

    result
  end

  def extract_spreadsheet_id(url)
    return url if url.blank?

    # Extract Google Spreadsheet ID from URL
    match = url.match(%r{/spreadsheets/d/([a-zA-Z0-9-_]+)})
    match ? match[1] : url
  end

  def parse_hours(hours)
    return nil if hours.nil?

    hours.to_f
  end
end
