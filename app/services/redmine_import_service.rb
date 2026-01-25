class RedmineImportService
  attr_reader :errors, :task, :project

  def initialize(redmine_id, project_id)
    @redmine_id = redmine_id
    @project = Project.find(project_id)
    @errors = []
    @task = nil
  end

  def import
    Rails.logger.info "Start import task from Redmine: #{@redmine_id}"

    begin
      issue_data = fetch_issue_from_redmine

      return false if issue_data.nil?

      create_or_update_task(issue_data)

      import_subtasks_from_sheets
      import_test_cases_if_available
      import_bugs_if_available

      Rails.logger.info "Import task thành công: #{ensure_utf8(@task.title)}"
      true
    rescue StandardError => e
      error_msg = ensure_utf8(e.message)
      @errors << "Lỗi khi import task: #{error_msg}"
      Rails.logger.error "RedmineImportService Error: #{error_msg}\n#{e.backtrace.join("\n")}"
      false
    end
  end

  private

  def fetch_issue_from_redmine
    unless @redmine_id.to_s.match?(/^\d+$/)
      @errors << 'Please provide issue ID (number) instead of name'
      return nil
    end

    issue_data = RedmineService.get_issues(@redmine_id)
    if issue_data.nil?
      @errors << "Cannot find issue from Redmine with ID: #{@redmine_id}"
      return nil
    end

    issue_data
  end

  def create_or_update_task(issue_data)
    @task = @project.tasks.find_or_initialize_by(
      title: ensure_utf8(issue_data['subject'])
    )

    @task.assign_attributes(task_attributes(issue_data))

    unless @task.save
      @errors << "Cannot save task: #{ensure_utf8(@task.errors.full_messages.join(', '))}"
      raise 'Cannot save task'
    end

    @task
  end

  def task_attributes(issue_data)
    custom_fields = parse_custom_fields(issue_data['custom_fields'] || [])
    internal_parent_id = find_internal_parent_id(issue_data)

    build_task_attributes(issue_data, custom_fields, internal_parent_id)
  end

  def find_internal_parent_id(issue_data)
    parent_redmine_id = issue_data.dig('parent', 'id')
    return nil unless parent_redmine_id.present?

    parent_task = Task.find_by(redmine_id: parent_redmine_id.to_s)
    parent_task&.id
  end

  def build_task_attributes(issue_data, custom_fields, internal_parent_id)
    {
      redmine_id: @redmine_id.to_s,
      parent_id: internal_parent_id,
      description: ensure_utf8(issue_data['description']),
      status: ensure_utf8(issue_data.dig('status', 'name')),
      estimated_time: parse_hours(issue_data['estimated_hours']),
      spent_time: parse_hours(issue_data['spent_hours']),
      percent_done: issue_data['done_ratio'],
      start_date: issue_data['start_date'],
      due_date: issue_data['due_date'],
      testcase_link: ensure_utf8(custom_fields['testcase_link']),
      number_of_test_cases: custom_fields['number_of_test_cases'],
      bug_link: ensure_utf8(custom_fields['bug_link']),
      stg_bugs_vn: custom_fields['stg_bugs_vn'],
      stg_bugs_jp: custom_fields['stg_bugs_jp'],
      prod_bugs: custom_fields['production_bugs'],
      created_by_name: ensure_utf8(issue_data.dig('assigned_to', 'name'))
    }
  end

  def parse_custom_fields(custom_fields)
    result = {}

    custom_fields.each do |field|
      name = ensure_utf8(field['name']).downcase.strip.gsub(/ +/, '_').gsub(/[()]/, '')
      value = field['value']
      # Rails.logger.info "name: #{name}, value: #{value}"
      result[name] = value
    end

    result
  end

  def extract_spreadsheet_id(url)
    return url if url.blank?

    # Extract Google Spreadsheet ID từ URL
    # Format: https://docs.google.com/spreadsheets/d/SPREADSHEET_ID/edit
    match = url.match(%r{/spreadsheets/d/([a-zA-Z0-9_-]+)})
    match ? match[1] : url
  end

  def parse_hours(hours)
    return nil if hours.nil?

    hours.to_f
  end

  def import_subtasks_from_sheets
    return unless @task.testcase_link.present?
    return if @task.parent_id.present?

    sheet_names = fetch_sheet_names_for_subtasks
    return unless sheet_names&.length.to_i > 1

    Rails.logger.info "Creating subtasks from #{sheet_names.length} sheets for task: #{@task.id}"
    create_subtasks_from_sheets(sheet_names)
  end

  def fetch_sheet_names_for_subtasks
    spreadsheet_id = extract_spreadsheet_id(@task.testcase_link)
    google_service = GoogleSheetService.new
    google_service.get_all_sheet_names(spreadsheet_id)
  end

  def create_subtasks_from_sheets(sheet_names)
    sheet_names.each do |name|
      name_utf8 = ensure_utf8(name)
      next if name_utf8.match?(/summary|template|settings|master/i)

      subtask = @task.subtasks.find_or_initialize_by(title: name_utf8)
      subtask.assign_attributes(subtask_attributes(name_utf8))
      subtask.save!
    end
  end

  def subtask_attributes(name_utf8)
    {
      project_id: @project.id,
      description: "Subtask automatic created from sheet: #{name_utf8}",
      status: @task.status,
      start_date: @task.start_date,
      due_date: @task.due_date,
      created_by_name: @task.created_by_name
    }
  end

  def import_test_cases_if_available
    return unless @task.testcase_link.present?

    Rails.logger.info "Found testcase link: #{@task.testcase_link}, start import test cases..."

    # Import test cases từ Google Sheet
    spreadsheet_id = extract_spreadsheet_id(@task.testcase_link)
    import_service = TestCaseImportService.new(@task, spreadsheet_id)

    if import_service.import
      Rails.logger.info "Import test cases successfully: #{import_service.imported_count} test cases"

      @task.update(number_of_test_cases: import_service.imported_count)
    else
      import_service.errors.each do |err|
        @errors << ensure_utf8(err)
      end
      Rails.logger.warn "Import test cases failed: #{import_service.errors.join(', ')}"
    end
  end

  def import_bugs_if_available
    return unless @task.bug_link.present?

    Rails.logger.info "Found bug link: #{@task.bug_link}, start import bugs..."

    spreadsheet_id = extract_spreadsheet_id(@task.bug_link)
    import_service = BugImportService.new(@task, spreadsheet_id)

    if import_service.import
      new_count = import_service.imported_count
      updated_count = import_service.updated_count
      Rails.logger.info "Import bugs successfully: #{new_count} new, #{updated_count} updated"
    else
      import_service.errors.each do |err|
        @errors << ensure_utf8(err)
      end
      Rails.logger.warn "Import bugs failed: #{import_service.errors.join(', ')}"
    end
  end

  def ensure_utf8(str)
    str = str.to_s
    str = str.dup if str.frozen?
    str.force_encoding('UTF-8').scrub
  end
end
