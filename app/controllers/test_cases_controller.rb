class TestCasesController < ApplicationController
  before_action :set_task, only: [ :new, :create, :import_from_sheet ]
  before_action :set_test_case, only: [ :show, :edit, :update, :destroy, :soft_delete ]

  # GET /test_cases or /tasks/:task_id/test_cases
  def index
    if params[:task_id]
      @task = Task.find(params[:task_id])
      @test_cases = @task.test_cases.active.includes(:created_by, :test_steps)
    else
      @test_cases = TestCase.active.includes(:task, :created_by, :test_steps)
    end

    # Filters
    @test_cases = @test_cases.by_type(params[:test_type]) if params[:test_type].present?
    @test_cases = @test_cases.by_target(params[:target]) if params[:target].present?

    respond_to do |format|
      format.html
      format.json { render json: @test_cases.as_json(include: [ :test_steps, :created_by ]) }
    end
  end

  # GET /test_cases/:id
  def show
    respond_to do |format|
      format.html
      format.json do
        render json: @test_case.as_json(
          include: {
            test_steps: {
              include: :test_step_contents
            },
            created_by: {},
            task: {}
          }
        )
      end
    end
  end

  # GET /tasks/:task_id/test_cases/new
  def new
    @test_case = @task.test_cases.build
  end

  # GET /test_cases/:id/edit
  def edit
  end

  # POST /tasks/:task_id/test_cases
  def create
    @test_case = @task.test_cases.build(test_case_params)
    @test_case.created_by = current_user_or_default

    if @test_case.save
      # Tạo test steps từ params nếu có
      create_test_steps_from_params if params[:test_steps].present?

      respond_to do |format|
        format.html { redirect_to @test_case, notice: "Create test case successfully." }
        format.json { render json: @test_case, status: :created }
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: { errors: @test_case.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /test_cases/:id
  def update
    if @test_case.update(test_case_params)
      # Cập nhật test steps nếu có
      update_test_steps_from_params if params[:test_steps].present?

      respond_to do |format|
        format.html { redirect_to @test_case, notice: "Update test case successfully." }
        format.json { render json: @test_case }
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: { errors: @test_case.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /test_cases/:id
  def destroy
    @test_case.destroy
    respond_to do |format|
      format.html { redirect_to test_cases_path, notice: "Delete test case successfully." }
      format.json { head :no_content }
    end
  end

  # PATCH /test_cases/:id/soft_delete
  def soft_delete
    @test_case.soft_delete!
    respond_to do |format|
      format.html { redirect_to test_cases_path, notice: "Soft delete test case successfully." }
      format.json { head :no_content }
    end
  end

  # POST /tasks/:task_id/test_cases/import_from_sheet
  # Import test cases từ Google Sheet
  def import_from_sheet
    spreadsheet_id = params[:spreadsheet_id] || @task.testcase_link

    if spreadsheet_id.blank?
      respond_to do |format|
        format.html { redirect_to task_test_cases_path(@task), alert: "Please provide Spreadsheet ID or Link." }
        format.json { render json: { error: "Spreadsheet ID is required" }, status: :unprocessable_entity }
      end
      return
    end

    current_user = current_user_or_default

    import_service = TestCaseImportService.new(@task, spreadsheet_id, current_user)

    if import_service.import
      # Cập nhật số lượng test cases
      @task.update(number_of_test_cases: import_service.imported_count)

      respond_to do |format|
        format.html do
          redirect_to task_test_cases_path(@task),
                      notice: "Import successfully #{import_service.imported_count} test cases. Skipped: #{import_service.skipped_count}."
        end
        format.json do
          render json: {
            message: "Import successful",
            imported_count: import_service.imported_count,
            skipped_count: import_service.skipped_count,
            errors: import_service.errors
          }, status: :created
        end
      end
    else
      respond_to do |format|
        format.html do
          redirect_to task_test_cases_path(@task),
                      alert: "Import failed: #{import_service.errors.join(', ')}"
        end
        format.json do
          render json: { errors: import_service.errors }, status: :unprocessable_entity
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
  end

  def current_user_or_default
    # Giả sử bạn có authentication với current_user
    # Nếu chưa có, tạo user mặc định
    User.first || User.create!(
      name: "Admin",
      email: "admin@example.com"
    )
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
      :user_story_url
    )
  end

  def create_test_steps_from_params
    return unless params[:test_steps].is_a?(Array)

    params[:test_steps].each_with_index do |step_data, index|
      step = @test_case.test_steps.create!(
        step_number: index + 1,
        description: step_data[:description]
      )

      # Tạo action contents
      if step_data[:actions].present?
        create_step_contents(step, step_data[:actions], "action")
      end

      # Tạo expectation contents
      if step_data[:expectations].present?
        create_step_contents(step, step_data[:expectations], "expectation")
      end
    end
  end

  def update_test_steps_from_params
    # Xóa tất cả steps cũ và tạo mới
    @test_case.test_steps.destroy_all
    create_test_steps_from_params
  end

  def create_step_contents(step, contents, category)
    return unless contents.is_a?(Array)

    contents.each_with_index do |content_data, index|
      step.test_step_contents.create!(
        content_type: content_data[:type] || "text",
        content_value: content_data[:value],
        content_category: category,
        display_order: index
      )
    end
  end
end
