class BugsController < ApplicationController
  before_action :set_project
  before_action :set_task
  before_action :set_bug, only: %i[show edit update destroy restore soft_delete history]

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
      respond_to do |format|
        format.html { redirect_to project_task_bugs_path(@project, @task), notice: 'Bug has been created successfully.' }
        format.turbo_stream do
          @all_bugs = @task.bugs.active.order(id: :asc)
          @total_bugs = @all_bugs.count
          bug_index = @all_bugs.to_a.index(@bug) || @total_bugs
          render turbo_stream: turbo_stream.append('bugs-spreadsheet-list',
                                                   partial: 'bugs/spreadsheet_row',
                                                   locals: { bug: @bug, index: bug_index + 1 })
        end
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.turbo_stream do
          render turbo_stream: turbo_stream.prepend('flash-messages',
                                                    partial: 'shared/flash',
                                                    locals: { flash: { alert: "Failed to create bug: #{@bug.errors.full_messages.join(', ')}" } })
        end
      end
    end
  end

  def edit; end

  def update
    if @bug.update(bug_params)
      respond_to do |format|
        format.html { redirect_to project_task_bug_path(@project, @task, @bug), notice: 'Bug has been updated successfully.' }
        format.turbo_stream do
          @all_bugs = @task.bugs.active.order(id: :asc)
          bug_index = @all_bugs.to_a.index(@bug) || 0
          render turbo_stream: turbo_stream.replace("bug-row-#{@bug.id}",
                                                    partial: 'bugs/spreadsheet_row',
                                                    locals: { bug: @bug, index: bug_index + 1 })
        end
        format.json do
          render json: @bug.as_json.merge(
            formatted_value: helpers.format_content_with_media_links(@bug.send(bug_params.keys.first.to_s) || '')
          )
        end
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.turbo_stream do
          render turbo_stream: turbo_stream.prepend('flash-messages',
                                                    partial: 'shared/flash',
                                                    locals: { flash: { alert: "Failed to update bug: #{@bug.errors.full_messages.join(', ')}" } })
        end
        format.json { render json: { errors: @bug.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @bug.soft_delete!
    redirect_to project_task_bugs_path(@project, @task), notice: 'Bug has been deleted successfully.'
  end

  def soft_delete
    @bug.soft_delete!
    respond_to do |format|
      format.html { redirect_to project_task_bugs_path(@project, @task), notice: 'Bug archived successfully.' }
      format.turbo_stream do
        render turbo_stream: turbo_stream.remove("bug-row-#{@bug.id}")
      end
    end
  end

  def restore
    @bug.restore!
    redirect_to project_task_bugs_path(@project, @task), notice: 'Bug has been restored successfully.'
  end

  def history
    @history_logs = ActivityLog.where(trackable_type: 'Bug', trackable_id: @bug.id)
                               .reorder(created_at: :desc)

    @page = params[:page].presence&.to_i || 1
    @per_page = 1
    @total_logs = @history_logs.count
    @total_pages = (@total_logs.to_f / @per_page).ceil
    @history_logs = @history_logs.offset((@page - 1) * @per_page).limit(@per_page)

    render layout: false
  rescue StandardError => e
    @error_message = "#{e.class}: #{e.message}"
    Rails.logger.error "[BugHistoryError] #{@error_message}\n#{e.backtrace[0..10].join("\n")}"
    render layout: false
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
                                :image_video_url, :notes, :bug_type)
  end

  def extract_spreadsheet_id(url)
    match = url.match(%r{/spreadsheets/d/([a-zA-Z0-9_-]+)})
    match ? match[1] : url
  end
end
