class BugsController < ApplicationController
  before_action :set_project
  before_action :set_task
  before_action :set_bug, only: %i[show edit update destroy restore]

  def index
    # Sorting and Pagination
    @page = (params[:page] || 1).to_i
    @per_page = 20

    # Base scope - only show active (non-deleted) bugs
    @all_bugs = @task.bugs.active.order(id: :asc)
    @all_bugs = @all_bugs.by_category(params[:category]) if params[:category].present?
    @all_bugs = @all_bugs.by_priority(params[:priority]) if params[:priority].present?

    @total_bugs = @all_bugs.count
    @total_pages = (@total_bugs.to_f / @per_page).ceil

    # Paginated data
    offset = (@page - 1) * @per_page
    @bugs = @all_bugs.offset(offset).limit(@per_page)

    # Archived (soft-deleted) bugs for restoration modal
    @archived_bugs = @task.bugs.deleted.order(deleted_at: :desc)
  end

  def show; end

  def new
    @bug = @task.bugs.build
  end

  def create
    @bug = @task.bugs.build(bug_params)
    if @bug.save
      redirect_to project_task_bugs_path(@project, @task), notice: 'Bug has been created successfully.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @bug.update(bug_params)
      redirect_to project_task_bug_path(@project, @task, @bug), notice: 'Bug has been updated successfully.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @bug.soft_delete!
    redirect_to project_task_bugs_path(@project, @task), notice: 'Bug has been deleted successfully.'
  end

  def restore
    @bug.restore!
    redirect_to project_task_bugs_path(@project, @task), notice: 'Bug has been restored successfully.'
  end

  def import_from_sheet
    if @task.bug_link.blank?
      redirect_to project_task_bugs_path(@project, @task), alert: 'Task has no bug link to import from.'
      return
    end

    spreadsheet_id = extract_spreadsheet_id(@task.bug_link)
    wipe_existing = params[:wipe_existing] == '1'
    import_service = BugImportService.new(@task, spreadsheet_id, wipe_existing: wipe_existing)

    if import_service.import
      notice = "Import successful: #{import_service.imported_count} new, #{import_service.updated_count} updated."
      redirect_to project_task_bugs_path(@project, @task), notice: notice
    else
      alert = "Import failed: #{import_service.errors.join(', ')}"
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
    @bug = Bug.unscoped.find_by!(id: params[:id], task_id: @task.id)
  end

  def bug_params
    params.require(:bug).permit(:title, :content, :application, :category, :priority, :status, :dev_id, :tester_id,
                                :image_video_url, :notes)
  end

  def extract_spreadsheet_id(url)
    match = url.match(%r{/spreadsheets/d/([a-zA-Z0-9_-]+)})
    match ? match[1] : url
  end
end
