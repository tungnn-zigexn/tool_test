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
