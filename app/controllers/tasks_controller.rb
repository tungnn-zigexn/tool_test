class TasksController < ApplicationController
  before_action :set_project, only: %i[new create import_from_redmine import_from_redmine_url]
  before_action :set_task, except: %i[index new create import_from_redmine import_from_redmine_url]
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
    @tasks = @tasks.where(assignee_id: params[:assignee_id]) if params[:assignee_id].present?

    # Search (My Tasks / Global Tasklist)
    if params[:q].present?
      query = params[:q].to_s.strip
      unless query.empty?
        like_query = "%#{query.downcase}%"
        @tasks = @tasks.where(
          "LOWER(tasks.title) LIKE :q OR LOWER(tasks.description) LIKE :q OR CAST(tasks.redmine_id AS TEXT) LIKE :raw_q",
          q: like_query,
          raw_q: "%#{query}%"
        )
      end
    end

    respond_to do |format|
      format.html
      format.json { render json: @tasks }
    end
  end

  # GET /tasks/:id or /projects/:project_id/tasks/:id
  def show
    @test_case = @task.test_cases.build
    
    # Pagination for test cases
    @test_cases_page = (params[:tc_page] || 1).to_i
    @test_cases_per_page = 10
    @all_test_cases = @task.test_cases.active.includes(:test_steps, :test_results).ordered
    @total_test_cases = @all_test_cases.size
    @total_tc_pages = (@total_test_cases.to_f / @test_cases_per_page).ceil
    
    # Paginated test cases
    tc_start = (@test_cases_page - 1) * @test_cases_per_page
    tc_end = tc_start + @test_cases_per_page - 1
    @paginated_test_cases = @all_test_cases.to_a[tc_start..tc_end] || []
    
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
      respond_to do |format|
        format.html { redirect_to project_task_path(@project, @task), notice: 'Create task successfully.' }
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
      format.html { redirect_to tasks_path, notice: 'Soft delete task successfully.' }
      format.json { head :no_content }
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

  # POST /projects/:project_id/tasks/import_from_redmine_url
  # Bulk import từ Redmine issues URL - chỉ lấy các issue "4. Testing"
  def import_from_redmine_url
    issues_url = params[:issues_url].presence || "#{RedmineService::BASE_URL}/issues.json"

    import_service = RedmineBulkImportService.new(@project.id, issues_url: issues_url)

    if import_service.import
      handle_bulk_import_success(import_service)
    else
      handle_bulk_import_failure(import_service)
    end
  end

  private

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
    count = service.imported_tasks.length
    respond_to do |format|
      format.html do
        redirect_to @project,
                    notice: "Bulk import hoàn tất: #{count} task(s) 4. Testing đã được import."
      end
      format.json do
        render json: {
          message: 'Bulk import successful',
          imported_count: count,
          tasks: service.imported_tasks.map { |t| { id: t.id, title: t.title } }
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

  def task_params
    params.require(:task).permit(
      :title, :description, :status, :assignee_id, :parent_id,
      :estimated_time, :spent_time, :percent_done, :start_date, :due_date,
      :testcase_link, :bug_link, :issue_link
    )
  end
end
