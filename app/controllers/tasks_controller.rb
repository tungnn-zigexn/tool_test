class TasksController < ApplicationController
  before_action :set_project,
                only: %i[new create import_from_redmine import_from_redmine_url list_redmine_issues redmine_projects 
                         import_selected_redmine_issues]
  before_action :set_task,
                except: %i[index new create import_from_redmine import_from_redmine_url list_redmine_issues 
                           redmine_projects import_selected_redmine_issues]
  # skip_before_action :verify_authenticity_token
  # skip_before_action :authenticate_user! # TODO: test postman
  # GET /tasks or /projects/:project_id/tasks
  def index
    if params[:project_id]
      @project = Project.find(params[:project_id])
      base_scope = @project.tasks.active.root_tasks
    else
      base_scope = Task.active.root_tasks
    end

    # Options for status filter
    @status_options = base_scope.distinct.pluck(:status).compact.sort

    @tasks = base_scope.includes(:project, :assignee, :test_cases)

    # Filters
    @tasks = @tasks.where(status: params[:status]) if params[:status].present?

    # ... rest of index ...
  end

  # GET /tasks/:id or /projects/:project_id/tasks/:id
  def show
    @test_case = @task.test_cases.build

    # Pagination for test cases
    @test_cases_page = (params[:tc_page] || 1).to_i
    @test_cases_per_page = 10
    
    # Sorting logic
    @tc_sort = params[:tc_sort] == 'desc' ? 'desc' : 'asc'
    @all_test_cases = @task.test_cases.active.includes(:test_steps, :test_results).order(id: @tc_sort.to_sym)
    @total_test_cases = @all_test_cases.size
    @total_tc_pages = (@total_test_cases.to_f / @test_cases_per_page).ceil

    # Paginated test cases
    tc_start = (@test_cases_page - 1) * @test_cases_per_page
    tc_end = tc_start + @test_cases_per_page - 1
    @paginated_test_cases = @all_test_cases.to_a[tc_start..tc_end] || []

    # Fetch archived (soft-deleted) test cases for the restoration modal
    @archived_test_cases = @task.test_cases.deleted.ordered
    @existing_titles = @task.test_cases.active.pluck(:title).uniq.compact.sort

    respond_to do |format|
      format.html
      format.json { render json: @task.as_json(include: %i[test_cases assignee]) }
    end
  end

  # GET /projects/:project_id/tasks/new
  def new
    @task = @project.tasks.build
  end

  # GET /tasks/:id/edit
  def edit; end

  # POST /projects/:project_id/tasks
  def create
    @task = @project.tasks.build(task_params)
    @task.created_by_name = current_user.name || current_user.email

    if @task.save
      tc_count, bug_count = perform_manual_imports

      notice = 'Create task successfully.'
      notice += " Imported #{tc_count} test cases." if tc_count.to_i.positive?
      notice += " Imported #{bug_count} bugs." if bug_count.to_i.positive?

      respond_to do |format|
        format.html { redirect_to project_task_path(@project, @task), notice: notice }
        format.json { render json: @task, status: :created }
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: { errors: @task.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /tasks/:id
  def update
    if @task.update(task_params)
      respond_to do |format|
        format.html { redirect_to project_task_path(@task.project, @task), notice: 'Update task successfully.' }
        format.json { render json: @task }
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: { errors: @task.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /tasks/:id
  def destroy
    @task.destroy
    respond_to do |format|
      format.html { redirect_to tasks_path, notice: 'Delete task successfully.' }
      format.json { head :no_content }
    end
  end

  # PATCH /tasks/:id/soft_delete
  def soft_delete
    @task.soft_delete!
    respond_to do |format|
      format.html { redirect_to project_path(@task.project), notice: 'Soft delete task successfully.' }
      format.json { head :no_content }
    end
  end

  # PATCH /tasks/:id/restore
  def restore
    @task.restore!
    respond_to do |format|
      format.html { redirect_to project_path(@task.project), notice: 'Restore task successfully.' }
      format.json { render json: @task }
    end
  end

  # POST /projects/:project_id/tasks/import_from_redmine
  # Import task from Redmine based on issue ID
  def import_from_redmine
    issue_id = params[:issue_id]

    if issue_id.blank?
      handle_missing_issue_id
      return
    end

    import_service = RedmineImportService.new(issue_id, @project.id)

    if import_service.import
      handle_import_success(import_service)
    else
      handle_import_failure(import_service)
    end
  end

  # GET /projects/:project_id/tasks/redmine_projects
  # List Redmine projects (id, name, identifier) for dropdown.
  def redmine_projects
    projects = RedmineService.get_projects_list
    render json: { projects: projects }
  end

  # POST /tasks/:id/create_subtask
  def create_subtask
    @subtask = @task.subtasks.build(task_params)
    @subtask.project = @project
    @subtask.created_by_name = current_user.name || current_user.email

    if @subtask.save
      redirect_to project_task_path(@project, @task), notice: 'Subtask created successfully.'
    else
      redirect_to project_task_path(@project, @task), alert: "Failed to create subtask: #{@subtask.errors.full_messages.join(', ')}"
    end
  end

  # POST /tasks/:id/promote_to_subtask
  def promote_to_subtask
    function_name = params[:function]

    if function_name.blank?
      redirect_to project_task_path(@project, @task), alert: 'Function name is required.'
      return
    end

    # Create the subtask
    subtask_title = "#{@task.title} - #{function_name}"
    @subtask = @task.subtasks.create(
      project: @project,
      title: subtask_title.truncate(255),
      status: 'New',
      created_by_name: current_user.name || current_user.email
    )

    if @subtask.persisted?
      # Move test cases with the same title (which is our function display) to the subtask
      # Try title first, then function column
      test_cases_to_move = @task.test_cases.where(title: function_name)
      test_cases_to_move = @task.test_cases.where(function: function_name) if test_cases_to_move.none?

      count = test_cases_to_move.count
      test_cases_to_move.update_all(task_id: @subtask.id)

      # Update counts for both parent and subtask
      @task.update(number_of_test_cases: @task.test_cases.active.count)
      @subtask.update(number_of_test_cases: @subtask.test_cases.active.count)

      redirect_to project_task_path(@project, @subtask),
                  notice: "Promoted '#{function_name}' to subtask successfully. Moved #{count} test cases."
    else
      redirect_to project_task_path(@project, @task), 
                  alert: "Failed to create subtask: #{@subtask.errors.full_messages.join(', ')}"
    end
  end

  # POST /tasks/:id/update_device_config
  def update_device_config
    if @task.update(device_config: params[:device_config])
      redirect_to project_task_path(@project, @task), notice: 'Cấu hình Device đã được cập nhật thành công.'
    else
      redirect_to project_task_path(@project, @task), alert: 'Có lỗi xảy ra khi cập nhật cấu hình Device.'
    end
  end

  # POST /tasks/:id/promote_all_to_subtask
  def promote_all_to_subtask
    subtask_title = "#{@task.title} - All Test Cases"
    @subtask = @task.subtasks.create(
      project: @project,
      title: subtask_title.truncate(255),
      status: 'New',
      created_by_name: current_user.name || current_user.email
    )

    if @subtask.persisted?
      test_cases_to_move = @task.test_cases.active
      count = test_cases_to_move.count
      test_cases_to_move.update_all(task_id: @subtask.id)

      # Update counts for both parent and subtask
      @task.update(number_of_test_cases: @task.test_cases.active.count)
      @subtask.update(number_of_test_cases: @subtask.test_cases.active.count)

      redirect_to project_task_path(@project, @subtask),
                  notice: "Moved all #{count} test cases to new subtask successfully."
    else
      redirect_to project_task_path(@project, @task),
                  alert: "Failed to create subtask: #{@subtask.errors.full_messages.join(', ')}"
    end
  end

  # GET /projects/:project_id/tasks/list_redmine_issues
  # List Redmine "4. Testing" issues with already_imported flag. Filter by Redmine project (ID hoặc identifier) and date range.
  def list_redmine_issues
    issues_url = params[:issues_url].presence || "#{RedmineService::BASE_URL}/issues.json"
    redmine_project_input = params[:redmine_project_id].to_s.strip.presence
    redmine_project_id = RedmineService.resolve_project_id(redmine_project_input) if redmine_project_input
    if redmine_project_input.present? && redmine_project_id.blank?
      render json: { issues: [], total_count: 0, errors: ['Không tìm thấy project Redmine với ID hoặc identifier đã nhập.'] }, status: :unprocessable_entity
      return
    end
    start_date, end_date = bulk_list_date_range

    list_service = RedmineBulkListService.new(@project.id, issues_url: issues_url)
    issues = list_service.list(redmine_project_id: redmine_project_id, created_on_from: start_date, created_on_to: end_date)

    render json: {
      issues: issues,
      total_count: issues.size,
      errors: list_service.errors
    }, status: list_service.errors.any? ? :unprocessable_entity : :ok
  end

  # POST /projects/:project_id/tasks/import_from_redmine_url
  # Bulk import từ Redmine issues URL - chỉ lấy các issue "4. Testing"
  def import_from_redmine_url
    issues_url = params[:issues_url].presence || "#{RedmineService::BASE_URL}/issues.json"
    issue_ids = params[:issue_ids].present? ? params[:issue_ids].reject(&:blank?) : nil

    import_service = RedmineBulkImportService.new(@project.id, issues_url: issues_url)

    if import_service.import(issue_ids: issue_ids)
      handle_bulk_import_success(import_service)
    else
      handle_bulk_import_failure(import_service)
    end
  end

  # POST /projects/:project_id/tasks/import_selected_redmine_issues
  # Import only selected Redmine issue IDs (4. Testing).
  def import_selected_redmine_issues
    issue_ids = params[:issue_ids].present? ? params[:issue_ids].reject(&:blank?) : nil

    if issue_ids.blank?
      respond_to do |format|
        format.html { redirect_to @project, alert: 'Vui lòng chọn ít nhất một task để import.' }
        format.json { render json: { error: 'issue_ids is required' }, status: :unprocessable_entity }
      end
      return
    end

    import_service = RedmineBulkImportService.new(@project.id)
    import_service.import_by_issue_ids(issue_ids)

    if import_service.errors.empty? || import_service.imported_tasks.any?
      handle_bulk_import_success(import_service)
    else
      handle_bulk_import_failure(import_service)
    end
  end

  private

  def bulk_list_date_range
    preset = params[:date_preset].to_s
    start_param = params[:start_date].to_s
    end_param = params[:end_date].to_s

    if start_param.present? && end_param.present?
      begin
        [Date.parse(start_param), Date.parse(end_param)]
      rescue ArgumentError
        [nil, nil]
      end
    elsif ProjectsController::DATE_PRESETS.key?(preset)
      r = ProjectsController::DATE_PRESETS[preset].call
      [r.begin, r.end]
    else
      # Mặc định 30 ngày gần đây nếu không có filter
      r = ProjectsController::DATE_PRESETS['last_30_days'].call
      [r.begin, r.end]
    end
  end

  def handle_missing_issue_id
    respond_to do |format|
      format.html { redirect_to @project, alert: 'Please provide Issue ID from Redmine.' }
      format.json { render json: { error: 'Issue ID is required' }, status: :unprocessable_entity }
    end
  end

  def handle_import_success(service)
    task = service.task
    count = task.number_of_test_cases
    respond_to do |format|
      format.html do
        redirect_to project_task_path(@project, task),
                    notice: "Import task successfully from Redmine. Imported #{count} test cases."
      end
      format.json do
        render json: {
          task: task.as_json(include: :test_cases),
          message: 'Import successful',
          test_cases_count: count
        }, status: :created
      end
    end
  end

  def handle_import_failure(service)
    respond_to do |format|
      format.html do
        redirect_to @project,
                    alert: "Import failed: #{service.errors.join(', ')}"
      end
      format.json do
        render json: { errors: service.errors }, status: :unprocessable_entity
      end
    end
  end

  def handle_bulk_import_success(service)
    tasks = service.imported_tasks
    task_count = tasks.length
    # Tổng test cases thực tế (đã import từ Sheet) để biết import test case có thành công không
    total_test_cases = tasks.sum { |t| t.test_cases.where(deleted_at: nil).count }
    tasks_with_tc = tasks.count { |t| t.test_cases.where(deleted_at: nil).exists? }

    notice = "Bulk import hoàn tất: #{task_count} task(s) 4. Testing đã import. "
    notice += if total_test_cases.positive?
                "Test cases: #{total_test_cases} (trong #{tasks_with_tc} task có test case)."
              elsif task_count.positive?
                'Test cases: 0 — kiểm tra testcase_link và Import từ Sheet trong từng task để lấy test case.'
              else
                'Không có task nào được import.'
              end

    respond_to do |format|
      format.html do
        redirect_to @project, notice: notice
      end
      format.json do
        render json: {
          message: 'Bulk import successful',
          imported_tasks_count: task_count,
          total_test_cases: total_test_cases,
          tasks_with_test_cases: tasks_with_tc,
          tasks: tasks.map do |t|
            { id: t.id, title: t.title, test_cases_count: t.test_cases.where(deleted_at: nil).count }
          end
        }, status: :created
      end
    end
  end

  def handle_bulk_import_failure(service)
    respond_to do |format|
      format.html do
        redirect_to @project,
                    alert: "Bulk import failed: #{service.errors.join('; ')}"
      end
      format.json do
        render json: { errors: service.errors }, status: :unprocessable_entity
      end
    end
  end

  def set_project
    @project = Project.find(params[:project_id]) if params[:project_id]
  end

  def set_task
    @task = Task.find(params[:id])
    @project = @task.project
  end

  def perform_manual_imports
    tc_count = 0
    bug_count = 0

    if @task.testcase_link.present?
      spreadsheet_id = extract_spreadsheet_id_from_url(@task.testcase_link)
      import_service = TestCaseImportService.new(@task, spreadsheet_id)
      tc_count = import_service.imported_count if import_service.import
    end

    if @task.bug_link.present?
      spreadsheet_id = extract_spreadsheet_id_from_url(@task.bug_link)
      import_service = BugImportService.new(@task, spreadsheet_id)
      bug_count = import_service.imported_count if import_service.import
    end

    [tc_count, bug_count]
  end

  def extract_spreadsheet_id_from_url(url)
    return url if url.blank?

    match = url.match(%r{/spreadsheets/d/([a-zA-Z0-9_-]+)})
    match ? match[1] : url
  end

  def task_params
    params.require(:task).permit(
      :title, :description, :status, :assignee_id, :parent_id,
      :estimated_time, :spent_time, :percent_done, :start_date, :due_date,
      :testcase_link, :bug_link, :issue_link, :device_config
    )
  end
end
