class ProjectHistoriesController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_admin

  # GET /project_histories
  # Hiển thị tất cả lịch sử của tất cả projects
  def index
    @project_histories = ProjectHistory
                         .includes(:project, :user)
                         .recent

    # Filter by project_id nếu có
    if params[:project_id].present?
      @project = Project.find(params[:project_id])
      @project_histories = @project_histories.by_project(params[:project_id])
    end

    # Filter by action nếu có
    @project_histories = @project_histories.by_action(params[:action_filter]) if params[:action_filter].present?

    respond_to do |format|
      format.html
      format.json { render json: @project_histories }
    end
  end

  # GET /project_histories/:id
  # Hiển thị chi tiết một lịch sử
  def show
    @project_history = ProjectHistory.find(params[:id])
    @project = @project_history.project

    respond_to do |format|
      format.html
      format.json { render json: @project_history }
    end
  end

  private

  def authorize_admin
    authorize! :manage, ProjectHistory
  end
end
