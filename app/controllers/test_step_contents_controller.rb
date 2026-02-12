class TestStepContentsController < ApplicationController
  def update
    @content = TestStepContent.find(params[:id])
    if @content.update(content_params)
      render json: @content.as_json.merge(
        formatted_value: view_context.format_content_with_media_links(@content.content_value)
      )
    else
      render json: { errors: @content.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def content_params
    params.require(:test_step_content).permit(:content_value)
  end
end
