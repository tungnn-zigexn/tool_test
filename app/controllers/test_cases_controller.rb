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
        format.turbo_stream { render :soft_delete }
        format.json { render json: @test_case, status: :created }
      end
    else
      set_existing_titles
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.turbo_stream do
          render turbo_stream: turbo_stream.prepend("flash-messages", partial: "shared/flash", locals: { flash: { alert: "Failed to create test case: #{@test_case.errors.full_messages.join(', ')}" } })
        end
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
      format.turbo_stream { render :soft_delete }
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
    set_spreadsheet_data
    respond_to do |format|
      format.html do
        redirect_to project_task_path(@task.project, @task),
                    notice: 'Test case restored successfully.'
      end
      format.turbo_stream { render :soft_delete }
      format.json { head :no_content }
    end
  end

  # GET /projects/:project_id/tasks/:task_id/test_cases/:id/history
  def history
    begin
      # Aggregated history: TestCase + TestStep + TestStepContent
      test_step = @test_case.test_step
      test_step_content_ids = test_step&.test_step_contents&.pluck(:id) || []

      @history_logs = ActivityLog.where(
        "(trackable_type = 'TestCase' AND trackable_id = ?) OR " \
        "(trackable_type = 'TestStep' AND trackable_id = ?) OR " \
        "(trackable_type = 'TestStepContent' AND trackable_id IN (?))",
        @test_case.id, test_step&.id, test_step_content_ids
      ).reorder(created_at: :desc)

      # Pagination: 1 log per page as requested by user
      @page = params[:page].presence&.to_i || 1
      @per_page = 1
      @total_logs = @history_logs.count
      @total_pages = (@total_logs.to_f / @per_page).ceil
      @history_logs = @history_logs.offset((@page - 1) * @per_page).limit(@per_page)
    rescue StandardError => e
      @error_message = "#{e.class}: #{e.message}"
      Rails.logger.error "[HistoryError] #{@error_message}\n#{e.backtrace[0..10].join("\n")}"
    end

    render layout: false
  end

  # POST /projects/:project_id/tasks/:task_id/test_cases/:id/revert
  def revert
    log = ActivityLog.find(params[:log_id])
    trackable = log.trackable
    field = params[:field]

    if log.metadata[field] && trackable
      old_value = log.metadata[field][0] # ActivityLog stores [old, new]

      # Map display names back to database fields if necessary (Loggable might store humanized names)
      # For now assuming field matches or mapping is handled
      db_field = field.downcase.gsub(' ', '_')

      if trackable.update(db_field => old_value)
        set_spreadsheet_data
        flash.now[:notice] = "Reverted #{field} to '#{old_value}'"
      else
        flash.now[:alert] = "Failed to revert: #{trackable.errors.full_messages.join(', ')}"
      end
    else
      flash.now[:alert] = "Could not find history data for #{field}"
    end

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to project_task_path(@project, @task), notice: "Reverted #{field} successfully" }
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
    @show_archived = params[:show_archived] == '1'

    query = @task.test_cases.includes(:test_steps, :test_results)
    query = @show_archived ? query.deleted : query.active

    @all_test_cases = query.order(Arel.sql("COALESCE(position, id) #{@tc_sort}"))
    @total_test_cases = @all_test_cases.size
    @total_tc_pages = (@total_test_cases.to_f / @test_cases_per_page).ceil

    # Ensure current page doesn't exceed total pages if there are test cases
    @test_cases_page = @total_tc_pages if @total_tc_pages.positive? && @test_cases_page > @total_tc_pages

    tc_start = (@test_cases_page - 1) * @test_cases_per_page
    @paginated_test_cases = @all_test_cases.limit(@test_cases_per_page).offset(tc_start).to_a
    @devices = @task.unique_devices.presence || %w[pc sp app]
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
      test_step_attributes: test_steps_params
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
