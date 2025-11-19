class ProjectsController < ApplicationController
  layout "demo"

  def index
    @projects = Project.all.order(created_at: :desc)
  end

  def show
    @project = Project.find(params[:id])
    @tasks = @project.tasks.includes(:test_cases, :subtasks).order(created_at: :desc)
  end
end
