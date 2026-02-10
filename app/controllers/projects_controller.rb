class ProjectsController < ApplicationController
  before_action :set_project, except: %i[index new create archived]
  before_action :authorize_admin, except: %i[index show archived]
  
  # Date presets definition
  DATE_PRESETS = {
    "today" => -> { Date.current..Date.current },
    "yesterday" => -> { Date.yesterday..Date.yesterday },
    "last_7_days" => -> { 6.days.ago.to_date..Date.current },
    "last_30_days" => -> { 29.days.ago.to_date..Date.current },
    "this_week" => -> { Date.current.beginning_of_week..Date.current },
    "last_week" => lambda {
      1.week.ago.beginning_of_week.to_date..1.week.ago.end_of_week.to_date
    },
    "this_month" => -> { Date.current.beginning_of_month..Date.current },
    "last_month" => lambda {
      1.month.ago.beginning_of_month.to_date..1.month.ago.end_of_month.to_date
    },
    "this_quarter" => -> { Date.current.beginning_of_quarter..Date.current },
    "last_quarter" => lambda {
      1.quarter.ago.beginning_of_quarter.to_date..1.quarter.ago.end_of_quarter.to_date
    },
    "this_year" => -> { Date.current.beginning_of_year..Date.current },
    "last_year" => lambda {
      1.year.ago.beginning_of_year.to_date..1.year.ago.end_of_year.to_date
    }
  }.freeze
  
  def index
    projects_per_page = 12 # 12 projects for nice grid layout (3x4 or 4x3)
    page = (params[:page] || 1).to_i
    
    all_projects = Project.active.order(created_at: :desc)
    @total_projects = all_projects.count
    @total_pages = (@total_projects.to_f / projects_per_page).ceil
    @current_page = page
    
    # Paginate
    offset = (page - 1) * projects_per_page
    @projects = all_projects.limit(projects_per_page).offset(offset)

    respond_to do |format|
      format.html
      format.json { render json: @projects }
    end
  end

  def archived
    projects_per_page = 12
    page = (params[:page] || 1).to_i
    
    all_archived = Project.deleted.order(deleted_at: :desc)
    @total_projects = all_archived.count
    @total_pages = (@total_projects.to_f / projects_per_page).ceil
    @current_page = page
    
    # Paginate
    offset = (page - 1) * projects_per_page
    @projects = all_archived.limit(projects_per_page).offset(offset)

    respond_to do |format|
      format.html
      format.json { render json: @projects }
    end
  end

  def show
    # Calculate date range from params
    @selected_preset = params[:date_preset].to_s.presence
    
    if params[:start_date].present? && params[:end_date].present?
      # Custom date range
      @start_date = Date.parse(params[:start_date]) rescue nil
      @end_date = Date.parse(params[:end_date]) rescue nil
      @selected_preset = 'custom' if @start_date && @end_date
    elsif @selected_preset.present? && DATE_PRESETS.key?(@selected_preset)
      # Preset range
      range = DATE_PRESETS[@selected_preset].call
      @start_date = range.begin
      @end_date = range.end
    else
      # Default: last 30 days
      range = DATE_PRESETS['last_30_days'].call
      @start_date = range.begin
      @end_date = range.end
      @selected_preset = 'last_30_days'
    end
    
    Rails.logger.info "[DATE FILTER DEBUG] Project: #{@project.id}, Preset: #{@selected_preset}, Range: #{@start_date} to #{@end_date}"

    # 1. Toàn bộ tasks của project (áp dụng filter ngày) - Dùng cho thống kê
    @tasks = @project.tasks.active
    @tasks = @tasks.where(created_at: @start_date.beginning_of_day..@end_date.end_of_day) if @start_date && @end_date

    # 2. Base query cho danh sách tasks chính (Root tasks + Filter ngày)
    base_tasks = @project.root_tasks.includes(:assignee, :test_cases, :subtasks)
    base_tasks = base_tasks.where(created_at: @start_date.beginning_of_day..@end_date.end_of_day) if @start_date && @end_date

    # Search functionality
    if params[:q].present?
      search_query = params[:q].to_s.strip
      unless search_query.empty?
        like_query = "%#{search_query.downcase}%"
        base_tasks = base_tasks.where(
          "LOWER(tasks.title) LIKE :q OR CAST(tasks.id AS TEXT) LIKE :raw_q OR CAST(tasks.redmine_id AS TEXT) LIKE :raw_q",
          q: like_query,
          raw_q: "%#{search_query}%"
        )
      end
    end

    # Status filter
    if params[:status].present?
      base_tasks = base_tasks.where(status: params[:status])
    end

    # Pagination
    @tasks_page = (params[:page] || 1).to_i
    @tasks_per_page = 10
    @all_root_tasks = base_tasks.order(created_at: :desc)
    @total_tasks = @all_root_tasks.count(:all)
    @total_pages = (@total_tasks.to_f / @tasks_per_page).ceil
    
    # Paginated tasks
    tasks_start = (@tasks_page - 1) * @tasks_per_page
    tasks_end = tasks_start + @tasks_per_page - 1
    @root_tasks = @all_root_tasks.to_a[tasks_start..tasks_end] || []
    
    # Status options for filter dropdown
    @status_options = @tasks.distinct.pluck(:status).compact.sort

    # Danh sách Redmine project (theo tên) cho dropdown Bulk Import - hiện sẵn để user chọn
    @redmine_projects = begin
      current_user&.admin? ? RedmineService.get_projects_list : []
    rescue StandardError
      []
    end

    respond_to do |format|
      format.html
      format.json { render json: @project.as_json(include: { tasks: { include: :test_cases } }) }
    end
  end

  def new
    @project = Project.new
  end

  def create
    @project = Project.new(project_params)

    respond_to do |format|
      if @project.save
        format.html { redirect_to @project, notice: 'Project has been created successfully.' }
        format.json { render json: @project, status: :created, location: @project }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @project.errors, status: :unprocessable_entity }
      end
    end
  end

  def edit; end

  def update
    respond_to do |format|
      if @project.update(project_params)
        format.html { redirect_to @project, notice: 'Project has been updated successfully.' }
        format.json { render json: @project }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @project.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    is_archived = @project.deleted_at.present?

    begin
      @project.destroy!
      notice_msg = is_archived ? 'Project has been permanently deleted.' : 'Project has been deleted.'
      redirect_path = is_archived ? archived_projects_path : projects_path

      respond_to do |format|
        format.html { redirect_to redirect_path, notice: notice_msg }
        format.json { head :no_content }
      end
    rescue StandardError => e
      respond_to do |format|
        format.html { redirect_back fallback_location: projects_path, alert: "Failed to delete project: #{e.message}" }
        format.json { render json: { error: e.message }, status: :unprocessable_entity }
      end
    end
  end

  def soft_delete
    respond_to do |format|
      if @project.soft_delete!
        format.html { redirect_to projects_path, notice: 'Project has been moved to archive.' }
        format.json { render json: @project }
      else
        format.html do
          redirect_back fallback_location: projects_path,
                        alert: "Failed to archive project: #{@project.errors.full_messages.join(', ')}"
        end
        format.json { render json: @project.errors, status: :unprocessable_entity }
      end
    end
  end

  def restore
    respond_to do |format|
      if @project.restore!
        format.html { redirect_to archived_projects_path, notice: 'Project has been restored successfully.' }
        format.json { render json: @project }
      else
        format.html do
          redirect_back fallback_location: archived_projects_path,
                        alert: "Failed to restore project: #{@project.errors.full_messages.join(', ')}"
        end
        format.json { render json: @project.errors, status: :unprocessable_entity }
      end
    end
  end

  private

  def set_project
    @project = Project.find(params[:id])
  end

  def project_params
    params.require(:project).permit(:name, :description)
  end

  def authorize_admin
    authorize! :manage, Project
  end
end
