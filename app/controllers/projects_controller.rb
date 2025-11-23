class ProjectsController < ApplicationController
  layout "demo"

  before_action :set_project, only: [:show, :edit, :update, :destroy, :soft_delete, :restore]

  def index
    @projects = Project.all.order(created_at: :desc)
  end

  def show
    @tasks = @project.tasks.includes(:test_cases, :subtasks).order(created_at: :desc)
  end

  def new
    @project = Project.new
  end

  def create
    @project = Project.new(project_params)

    if @project.save
      redirect_to @project, notice: "Project đã được tạo thành công."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @project.update(project_params)
      redirect_to @project, notice: "Project đã được cập nhật."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @project.destroy
    redirect_to projects_path, notice: "Project đã được xóa."
  end

  def soft_delete
    @project.update(deleted_at: Time.current)
    redirect_to projects_path, notice: "Project đã được xóa mềm."
  end

  def restore
    @project.update(deleted_at: nil)
    redirect_to projects_path, notice: "Project đã được khôi phục."
  end

  private

  def set_project
    @project = Project.find(params[:id])
  end

  def project_params
    params.require(:project).permit(:name, :description)
  end
end
