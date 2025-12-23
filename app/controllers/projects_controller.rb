class ProjectsController < ApplicationController
  skip_load_and_authorize_resource
  before_action :set_project, except: %i[index new create]
  # before_action :authorize_admin, only: [ :new, :create, :edit, :update, :destroy, :soft_delete, :restore ]
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate_user!
  def index
    @projects = Project.all.order(created_at: :desc)

    respond_to do |format|
      format.html
      format.json { render json: @projects }
    end
  end

  def show
    @tasks = @project.tasks.includes(
      :assignee,
      :test_cases,
      :subtasks
    ).order(created_at: :desc)

    # Filter root tasks (including orphaned tasks)
    # We load all tasks first to ensure associations are eager loaded as requested
    @all_tasks = @tasks.to_a
    task_ids = @all_tasks.to_set(&:id)

    # A task is a root if:
    # 1. parent_id is nil
    # 2. OR parent_id points to an ID that is NOT in the loaded task list (Orphan)
    @root_tasks = @all_tasks.select { |t| t.parent_id.nil? || !task_ids.include?(t.parent_id) }

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
    @project.destroy

    respond_to do |format|
      format.html { redirect_to projects_path, notice: 'Project has been deleted successfully.' }
      format.json { head :no_content }
    end
  end

  def soft_delete
    @project.update(deleted_at: Time.current)

    respond_to do |format|
      format.html { redirect_to projects_path, notice: 'Project has been soft deleted successfully.' }
      format.json { render json: @project }
    end
  end

  def restore
    @project.update(deleted_at: nil)

    respond_to do |format|
      format.html { redirect_to projects_path, notice: 'Project has been restored successfully.' }
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
end
