class BugsController < ApplicationController
  skip_load_and_authorize_resource
  before_action :set_project, only: [:index, :import_from_sheet]
  before_action :set_task, only: [:index, :import_from_sheet]

  def index
    @bugs = @task.bugs.order(created_at: :desc)
    @bugs = @bugs.by_category(params[:category]) if params[:category].present?
    @bugs = @bugs.by_priority(params[:priority]) if params[:priority].present?
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

  def extract_spreadsheet_id(url)
    match = url.match(%r{/spreadsheets/d/([a-zA-Z0-9_-]+)})
    match ? match[1] : url
  end
end
