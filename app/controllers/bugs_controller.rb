class BugsController < ApplicationController
  skip_load_and_authorize_resource
  before_action :set_project
  before_action :set_task
  before_action :set_bug, only: [:show, :edit, :update, :destroy]

  def index
    @bugs = @task.bugs.order(created_at: :desc)
    @bugs = @bugs.by_category(params[:category]) if params[:category].present?
    @bugs = @bugs.by_priority(params[:priority]) if params[:priority].present?
  end

  def show
  end

  def new
    @bug = @task.bugs.build
  end

  def create
    @bug = @task.bugs.build(bug_params)
    if @bug.save
      redirect_to project_task_bugs_path(@project, @task), notice: 'Bug đã được tạo thành công.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @bug.update(bug_params)
      redirect_to project_task_bug_path(@project, @task, @bug), notice: 'Bug đã được cập nhật thành công.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @bug.soft_delete
    redirect_to project_task_bugs_path(@project, @task), notice: 'Bug đã được xóa thành công.'
  end

  def import_from_sheet
    if @task.bug_link.blank?
      redirect_to project_task_bugs_path(@project, @task), alert: 'Task không có link bug để import.'
      return
    end

    spreadsheet_id = extract_spreadsheet_id(@task.bug_link)
    import_service = BugImportService.new(@task, spreadsheet_id)

    if import_service.import
      notice = "Import thành công: #{import_service.imported_count} mới, #{import_service.updated_count} cập nhật."
      redirect_to project_task_bugs_path(@project, @task), notice: notice
    else
      alert = "Import thất bại: #{import_service.errors.join(', ')}"
      redirect_to project_task_bugs_path(@project, @task), alert: alert
    end
  end

  private

  def set_project
    @project = Project.find(params[:project_id])
  end

  def set_task
    @task = @project.tasks.find(params[:task_id])
  end

  def set_bug
    @bug = @task.bugs.find(params[:id])
  end

  def bug_params
    params.require(:bug).permit(:title, :content, :application, :category, :priority, :status, :dev_id, :tester_id, :image_video_url, :notes)
  end

  def extract_spreadsheet_id(url)
    match = url.match(%r{/spreadsheets/d/([a-zA-Z0-9_-]+)})
    match ? match[1] : url
  end
end
