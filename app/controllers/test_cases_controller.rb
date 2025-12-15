class TestCasesController < ApplicationController
  skip_load_and_authorize_resource
  before_action :set_task, except: [ :index ]
  before_action :set_test_case, only: [ :show, :edit, :update, :destroy, :soft_delete ]
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate_user!

  # GET /test_cases or /projects/:project_id/tasks/:task_id/test_cases
  def index
    if params[:task_id]
      @task = Task.find(params[:task_id])
      @test_cases = @task.test_cases.active.includes(:test_steps, :created_by)
    else
      @test_cases = TestCase.active.includes(:task, :test_steps, :created_by)
    end

    # Filters
    @test_cases = @test_cases.where(test_type: params[:test_type]) if params[:test_type].present?
    @test_cases = @test_cases.where(target: params[:target]) if params[:target].present?

    respond_to do |format|
      format.html
      format.json { render json: @test_cases.as_json(include: [ :test_steps, :created_by ]) }
    end
  end

  # GET /projects/:project_id/tasks/:task_id/test_cases/:id
  def show
    respond_to do |format|
      format.html
      format.json do
        render json: @test_case.as_json(
          include: {
            test_steps: {
              include: :test_step_contents
            },
            created_by: { only: [ :id, :name, :email ] }
          }
        )
      end
    end
  end

  # GET /projects/:project_id/tasks/:task_id/test_cases/new
  def new
    @test_case = @task.test_cases.build
    # Build default step
    @test_case.test_steps.build(step_number: 1)
  end

  # GET /projects/:project_id/tasks/:task_id/test_cases/:id/edit
  def edit
  end

  # POST /projects/:project_id/tasks/:task_id/test_cases
  def create
    @test_case = @task.test_cases.build(test_case_params)
    @test_case.created_by = current_user

    if @test_case.save
      respond_to do |format|
        format.html do
          redirect_to [ @task.project, @task, @test_case ],
                      notice: "Test case created successfully."
        end
        format.json { render json: @test_case, status: :created }
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json do
          render json: { errors: @test_case.errors.full_messages },
                 status: :unprocessable_entity
        end
      end
    end
  end

  # PATCH/PUT /projects/:project_id/tasks/:task_id/test_cases/:id
  def update
    if @test_case.update(test_case_params)
      respond_to do |format|
        format.html do
          redirect_to [ @task.project, @task, @test_case ],
                      notice: "Test case updated successfully."
        end
        format.json { render json: @test_case }
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.json do
          render json: { errors: @test_case.errors.full_messages },
                 status: :unprocessable_entity
        end
      end
    end
  end

  # DELETE /projects/:project_id/tasks/:task_id/test_cases/:id
  def destroy
    @test_case.destroy
    respond_to do |format|
      format.html do
        redirect_to project_task_test_cases_path(@task.project, @task),
                    notice: "Test case deleted successfully."
      end
      format.json { head :no_content }
    end
  end

  # PATCH /projects/:project_id/tasks/:task_id/test_cases/:id/soft_delete
  def soft_delete
    @test_case.soft_delete!
    respond_to do |format|
      format.html do
        redirect_to project_task_test_cases_path(@task.project, @task),
                    notice: "Test case soft deleted successfully."
      end
      format.json { head :no_content }
    end
  end

  # POST /projects/:project_id/tasks/:task_id/test_cases/import_from_sheet
  def import_from_sheet
    spreadsheet_id = params[:spreadsheet_id]

    if spreadsheet_id.blank?
      respond_to do |format|
        format.html do
          redirect_to [ @task.project, @task ],
                      alert: "Please provide Google Sheet ID."
        end
        format.json do
          render json: { error: "Spreadsheet ID is required" },
                 status: :unprocessable_entity
        end
      end
      return
    end

    import_service = TestCaseImportService.new(@task, spreadsheet_id)

    if import_service.import
      respond_to do |format|
        format.html do
          redirect_to [ @task.project, @task ],
                      notice: "Imported #{import_service.imported_count} test cases successfully."
        end
        format.json do
          render json: {
            message: "Import successful",
            imported_count: import_service.imported_count,
            skipped_count: import_service.skipped_count
          }, status: :created
        end
      end
    else
      respond_to do |format|
        format.html do
          redirect_to [ @task.project, @task ],
                      alert: "Import failed: #{import_service.errors.join(', ')}"
        end
        format.json do
          render json: { errors: import_service.errors },
                 status: :unprocessable_entity
        end
      end
    end
  end

  private

  def set_task
    @task = Task.find(params[:task_id]) if params[:task_id]
  end

  def set_test_case
    @test_case = TestCase.find(params[:id])
    @task ||= @test_case.task
  end

  def test_case_params
    params.require(:test_case).permit(
      :title,
      :description,
      :expected_result,
      :test_type,
      :function,
      :target,
      :acceptance_criteria_url,
      :user_story_url,
      test_steps_attributes: [
        :id,
        :step_number,
        :description,
        :function,
        :display_order,
        :_destroy,
        test_step_contents_attributes: [
          :id,
          :content_type,
          :content_value,
          :content_category,
          :is_expected,
          :display_order,
          :_destroy
        ]
      ]
    )
  end
end
