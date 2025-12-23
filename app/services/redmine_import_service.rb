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

      import_test_cases_if_available

      Rails.logger.info "Import task thành công: #{@task.title}"
      true
    rescue StandardError => e
      @errors << "Lỗi khi import task: #{e.message}"
      Rails.logger.error "RedmineImportService Error: #{e.message}\n#{e.backtrace.join("\n")}"
      false
    end
  end

  private

  def fetch_issue_from_redmine
    issue_data = if @redmine_id.to_s.match?(/^\d+$/)
                   RedmineService.get_issues(@redmine_id)
                 else
                   @errors << 'Please provide issue ID (number) instead of name'
                   return nil
                 end
    if issue_data.nil?
      @errors << "Cannot find issue from Redmine with ID: #{@redmine_id}"
      return nil
    end

    issue_data
  end

  def create_or_update_task(issue_data)
    @task = @project.tasks.find_or_initialize_by(
      title: issue_data['subject']
    )

    @task.assign_attributes(task_attributes(issue_data))

    unless @task.save
      @errors << "Cannot save task: #{@task.errors.full_messages.join(', ')}"
      raise 'Cannot save task'
    end

    @task
  end

  def task_attributes(issue_data)
    custom_fields = parse_custom_fields(issue_data['custom_fields'] || [])
    {
      redmine_id: @redmine_id,
      parent_id: issue_data.dig('parent', 'id'),
      description: issue_data['description'],
      status: issue_data.dig('status', 'name'),
      estimated_time: parse_hours(issue_data['estimated_hours']),
      spent_time: parse_hours(issue_data['spent_hours']),
      percent_done: issue_data['done_ratio'],
      start_date: issue_data['start_date'],
      due_date: issue_data['due_date'],
      testcase_link: custom_fields['testcase_link'],
      number_of_test_cases: custom_fields['number_of_test_cases'],
      bug_link: custom_fields['bug_link'],
      stg_bugs_vn: custom_fields['stg_bugs_vn'],
      stg_bugs_jp: custom_fields['stg_bugs_jp'],
      prod_bugs: custom_fields['production_bugs'],
      created_by_name: issue_data.dig('assigned_to', 'name')
    }
  end

  def parse_custom_fields(custom_fields)
    result = {}

    custom_fields.each do |field|
      name = field['name'].to_s.downcase.strip.gsub(/ +/, '_').gsub(/[()]/, '')
      value = field['value']
      Rails.logger.info "name: #{name}, value: #{value}"
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

  # def find_or_create_user(user_data)
  #   return nil if user_data.nil?

  #   # Tìm hoặc tạo user
  #   email = "#{user_data['name'].parameterize}@example.com" # Tạo email giả
  #   User.find_or_create_by(email: email) do |user|
  #     user.name = user_data["name"]
  #   end
  # end

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
      @errors.concat(import_service.errors)
      Rails.logger.warn "Import test cases failed: #{import_service.errors.join(', ')}"
    end
  end
end
