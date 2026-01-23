class ProjectsController < ApplicationController
  skip_load_and_authorize_resource
  before_action :set_project, except: %i[index new create archived]
  before_action :authorize_admin, except: %i[index show archived]
  # skip_before_action :verify_authenticity_token
  # skip_before_action :authenticate_user! # TODO: test postman
  def index
    @projects = Project.active.order(created_at: :desc)

    respond_to do |format|
      format.html
      format.json { render json: @projects }
    end
  end

  def archived
    @projects = Project.deleted.order(deleted_at: :desc)

    respond_to do |format|
      format.html
      format.json { render json: @projects }
    end
  end

  def show
    @root_tasks = @project.root_tasks.includes(
      :assignee,
      :test_cases,
      :subtasks
    ).order(created_at: :desc)

    # We still need @tasks for some stats in the view (test cases sum etc)
    @tasks = @project.tasks.active

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
        # Log history
        log_project_history(@project, 'create', nil, @project.attributes.to_json)

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
    # Lưu giá trị cũ trước khi update
    old_attributes = @project.attributes.clone

    respond_to do |format|
      if @project.update(project_params)
        # Log history
        log_project_history(@project, 'update', old_attributes.to_json, @project.attributes.to_json)

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
    project_attributes = @project.attributes.to_json

    @project.destroy

    # Log history
    log_project_history(@project, 'destroy', project_attributes, nil)

    respond_to do |format|
      redirect_path = is_archived ? archived_projects_path : projects_path
      format.html { redirect_to redirect_path, notice: 'Project has been permanently deleted.' }
      format.json { head :no_content }
    end
  end

  def soft_delete
    old_attributes = @project.attributes.clone

    @project.update(deleted_at: Time.current)

    # Log history
    log_project_history(@project, 'soft_delete', old_attributes.to_json, @project.attributes.to_json)

    respond_to do |format|
      format.html { redirect_to projects_path, notice: 'Project has been soft deleted successfully.' }
      format.json { render json: @project }
    end
  end

  def restore
    old_attributes = @project.attributes.clone

    @project.update(deleted_at: nil)

    # Log history
    log_project_history(@project, 'restore', old_attributes.to_json, @project.attributes.to_json)

    respond_to do |format|
      format.html { redirect_to archived_projects_path, notice: 'Project has been restored successfully.' }
      format.json { render json: @project }
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

  # Helper method để log history
  def log_project_history(project, action, old_value, new_value)
    ProjectHistory.create(
      project: project,
      user: current_user,
      action: action,
      old_value: old_value,
      new_value: new_value
    )
  rescue StandardError => e
    Rails.logger.error "Failed to log project history: #{e.message}"
  end
end
