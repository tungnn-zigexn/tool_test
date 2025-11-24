class DashboardController < ApplicationController
  skip_load_and_authorize_resource

  def index
    if current_user.admin?
      redirect_to admin_dashboard_path
    else
      redirect_to user_dashboard_path
    end
  end

  def admin
    authorize! :manage, :all
    @users_count = User.active.count
    @projects_count = Project.active.count
    @tasks_count = Task.active.root_tasks.count
    @recent_users = User.active.order(created_at: :desc).limit(5)
    @recent_projects = Project.active.order(created_at: :desc).limit(5)
  end

  def user
    @projects = Project.active.order(created_at: :desc)
  end
end
