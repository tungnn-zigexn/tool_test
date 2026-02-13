class TestCasesController < ApplicationController
  before_action :set_task, except: [:index]
  before_action :set_test_case, except: %i[index new create import_from_sheet]

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
      format.json { render json: @test_cases.as_json(include: %i[test_steps created_by]) }
    end
  end

  # GET /projects/:project_id/tasks/:task_id/test_cases/:id
  def show
    # Calculate next/prev IDs and current index for modal navigation/display
    active_test_cases = @task.test_cases.active.ordered
    current_index = active_test_cases.index(@test_case)
    @test_case_index = (current_index || 0) + 1

    if current_index
      @prev_test_case = active_test_cases[current_index - 1] if current_index.positive?
      @next_test_case = active_test_cases[current_index + 1] if current_index < active_test_cases.size - 1
    end

    respond_to do |format|
      format.html
      format.turbo_stream
      format.json do
        render json: @test_case.as_json(
          include: {
            test_steps: {
              include: :test_step_contents
            },
            created_by: { only: %i[id name email] }
          }
        )
      end
    end
  end

  def new
    @test_case = @task.test_cases.build
    set_existing_titles
    # Build default step
    @test_case.test_steps.build(step_number: 1)
  end

  # GET /projects/:project_id/tasks/:task_id/test_cases/:id/edit
  def edit
    set_existing_titles
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  # POST /projects/:project_id/tasks/:task_id/test_cases
  def create
    @test_case = @task.test_cases.build(test_case_params)
    @test_case.created_by = current_user

    # Handle insert position
    if params[:insert_after].present?
      after_tc = @task.test_cases.find_by(id: params[:insert_after])
      if after_tc&.position
        new_position = after_tc.position + 1
        TestCase.insert_at_position!(@task, new_position)
        @test_case.position = new_position
      end
    end

    if @test_case.save
      set_existing_titles
      set_spreadsheet_data
      respond_to do |format|
        format.html do
          redirect_to project_task_path(@task.project, @task),
                      notice: 'Test case created successfully.'
        end
        format.turbo_stream
        format.json { render json: @test_case, status: :created }
      end
    else
      set_existing_titles
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.turbo_stream { render :new, status: :unprocessable_entity }
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
      set_existing_titles
      set_spreadsheet_data
      respond_to do |format|
        format.html do
          redirect_to [@task.project, @task, @test_case],
                      notice: 'Test case updated successfully.'
        end
        format.turbo_stream
        format.json { render json: @test_case }
      end
    else
      set_existing_titles
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.turbo_stream { render :edit, status: :unprocessable_entity }
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
    set_spreadsheet_data
    respond_to do |format|
      format.html do
        redirect_to project_task_path(@task.project, @task),
                    notice: 'Test case deleted successfully.'
      end
      format.turbo_stream
      format.json { head :no_content }
    end
  end

  # PATCH /projects/:project_id/tasks/:task_id/test_cases/:id/soft_delete
  def soft_delete
    @test_case.soft_delete!
    set_spreadsheet_data
    respond_to do |format|
      format.html do
        redirect_to project_task_path(@task.project, @task),
                    notice: 'Test case soft deleted successfully.'
      end
      format.turbo_stream
      format.json { head :no_content }
    end
  end

  # PATCH /projects/:project_id/tasks/:task_id/test_cases/:id/restore
  def restore
    @test_case.restore!
    respond_to do |format|
      format.html do
        redirect_to project_task_path(@task.project, @task),
                    notice: 'Test case restored successfully.'
      end
      format.json { head :no_content }
    end
  end

  # POST /projects/:project_id/tasks/:task_id/test_cases/import_from_sheet
  def import_from_sheet
    spreadsheet_id = extract_spreadsheet_id(params[:spreadsheet_id])

    if spreadsheet_id.blank?
      handle_missing_spreadsheet_id
      return
    end

    wipe_existing = params[:wipe_existing] == '1'
    import_service = TestCaseImportService.new(@task, spreadsheet_id, wipe_existing: wipe_existing)

    if import_service.import
      handle_import_success(import_service)
    else
      handle_import_failure(import_service)
    end
  end

  private

  def set_spreadsheet_data
    @test_cases_per_page = 10
    @test_cases_page = params[:tc_page].to_i
    @test_cases_page = 1 if @test_cases_page < 1
    @tc_sort = params[:tc_sort] == 'desc' ? 'desc' : 'asc'
    
    @all_test_cases = @task.test_cases.active.includes(:test_steps, :test_results).order(Arel.sql("COALESCE(position, id) #{@tc_sort}"))
    @total_test_cases = @all_test_cases.size
    @total_tc_pages = (@total_test_cases.to_f / @test_cases_per_page).ceil

    # Ensure current page doesn't exceed total pages if there are test cases
    if @total_tc_pages > 0 && @test_cases_page > @total_tc_pages
      @test_cases_page = @total_tc_pages
    end

    tc_start = (@test_cases_page - 1) * @test_cases_per_page
    @paginated_test_cases = @all_test_cases.limit(@test_cases_per_page).offset(tc_start).to_a
    @devices = @task.unique_devices.presence || ['pc', 'sp', 'app']
    @tc_start_index = tc_start
  end

  def extract_spreadsheet_id(input)
    return input if input.blank?

    # Extract ID from Google Sheets URL if present
    if input.include?('docs.google.com/spreadsheets/d/')
      match = input.match(%r{/d/([^/]+)})
      match ? match[1] : input
    else
      input.strip
    end
  end

  def handle_missing_spreadsheet_id
    respond_to do |format|
      format.html { redirect_to [@task.project, @task], alert: 'Please provide Google Sheet ID.' }
      format.json { render json: { error: 'Spreadsheet ID is required' }, status: :unprocessable_entity }
    end
  end

  def handle_import_success(service)
    respond_to do |format|
      format.html do
        redirect_to [@task.project, @task],
                    notice: "Imported #{service.imported_count} test cases successfully."
      end
      format.json do
        render json: {
          message: 'Import successful',
          imported_count: service.imported_count,
          skipped_count: service.skipped_count
        }, status: :created
      end
    end
  end

  def handle_import_failure(service)
    respond_to do |format|
      format.html do
        redirect_to [@task.project, @task],
                    alert: "Import failed: #{service.errors.join(', ')}"
      end
      format.json do
        render json: { errors: service.errors }, status: :unprocessable_entity
      end
    end
  end

  def set_task
    @task = Task.find(params[:task_id]) if params[:task_id]
    @project = @task&.project
  end

  def set_test_case
    @test_case = TestCase.find(params[:id])
    @task = @test_case.task if @task.nil?
    @project = @task&.project if @project.nil?
  end

  def set_existing_titles
    @existing_titles = @task&.test_cases&.active&.pluck(:title)&.uniq&.compact&.sort || []
  end

  def test_case_params
    params.require(:test_case).permit(
      :title, :description, :expected_result, :test_type, :function, :target, :note,
      :acceptance_criteria_url, :user_story_url,
      test_steps_attributes: test_steps_params
    )
  end

  def test_steps_params
    [
      :id, :step_number, :description, :function, :display_order, :_destroy,
      { test_step_contents_attributes: test_step_contents_params }
    ]
  end

  def test_step_contents_params
    %i[id content_type content_value content_category is_expected display_order _destroy]
  end
end
