class TasksController < ApplicationController
  skip_load_and_authorize_resource
  before_action :set_project, only: %i[new create import_from_redmine]
  before_action :set_task, except: %i[index new create import_from_redmine]
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate_user!

  # GET /tasks or /projects/:project_id/tasks
  def index
    if params[:project_id]
      @project = Project.find(params[:project_id])
      @tasks = @project.tasks.active.includes(:assignee, :test_cases)
    else
      @tasks = Task.active.includes(:project, :assignee, :test_cases)
    end

    # Filters
    @tasks = @tasks.where(status: params[:status]) if params[:status].present?
    @tasks = @tasks.where(assignee_id: params[:assignee_id]) if params[:assignee_id].present?

    respond_to do |format|
      format.html
      format.json { render json: @tasks }
    end
  end

  # GET /tasks/:id or /projects/:project_id/tasks/:id
  def show
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
        format.html { redirect_to @task, notice: 'Update task successfully.' }
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
      respond_to do |format|
        format.html { redirect_to @project, alert: 'Please provide Issue ID from Redmine.' }
        format.json { render json: { error: 'Issue ID is required' }, status: :unprocessable_entity }
      end
      return
    end

    import_service = RedmineImportService.new(issue_id, @project.id)

    if import_service.import
      respond_to do |format|
        format.html do
          redirect_to project_task_path(@project, import_service.task),
                      notice: "Import task successfully from Redmine. Imported #{import_service.task.number_of_test_cases} test cases."
        end
        format.json do
          render json: {
            task: import_service.task.as_json(include: :test_cases),
            message: 'Import successful',
            test_cases_count: import_service.task.number_of_test_cases
          }, status: :created
        end
      end
    else
      respond_to do |format|
        format.html do
          redirect_to @project,
                      alert: "Import failed: #{import_service.errors.join(', ')}"
        end
        format.json do
          render json: { errors: import_service.errors }, status: :unprocessable_entity
        end
      end
    end
  end

  private

  def set_project
    @project = Project.find(params[:project_id]) if params[:project_id]
  end

  def set_task
    @task = Task.find(params[:id])
  end

  def task_params
    params.require(:task).permit(
      :title,
      :description,
      :status,
      :assignee_id,
      :parent_id,
      :estimated_time,
      :spent_time,
      :percent_done,
      :start_date,
      :due_date,
      :testcase_link,
      :bug_link,
      :issue_link
    )
  end
end
