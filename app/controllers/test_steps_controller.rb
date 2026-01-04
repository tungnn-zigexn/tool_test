class TestStepsController < ApplicationController
  skip_load_and_authorize_resource
  before_action :set_test_case
  before_action :set_test_step

  # GET /projects/:project_id/tasks/:task_id/test_cases/:test_case_id/test_steps/:id/edit
  def edit; end

  # PATCH/PUT /projects/:project_id/tasks/:task_id/test_cases/:test_case_id/test_steps/:id
  def update
    if @test_step.update(test_step_params)
      redirect_to project_task_test_case_path(@project, @task, @test_case),
                  notice: 'Test step updated successfully.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /projects/:project_id/tasks/:task_id/test_cases/:test_case_id/test_steps/:id
  def destroy
    @test_step.destroy
    # NOTE: Auto-renumbering is handled by after_destroy callback in TestStep model
    redirect_to project_task_test_case_path(@project, @task, @test_case),
                notice: 'Test step deleted and remaining steps renumbered.'
  end

  private

  def set_test_case
    @project = Project.find(params[:project_id])
    @task = @project.tasks.find(params[:task_id])
    @test_case = @task.test_cases.find(params[:test_case_id])
  end

  def set_test_step
    @test_step = @test_case.test_steps.find(params[:id])
  end

  def test_step_params
    params.require(:test_step).permit(
      :step_number,
      :description,
      :function,
      :display_order,
      test_step_contents_attributes: %i[
        id
        content_type
        content_value
        content_category
        is_expected
        display_order
        _destroy
      ]
    )
  end
end
