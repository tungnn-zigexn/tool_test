class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Devise authentication
  before_action :authenticate_user!
  before_action :set_current_user

  private

  def set_current_user
    Current.user = current_user
  end

  # CanCanCan authorization
  load_and_authorize_resource unless: :devise_controller?

  # Handle exception CanCan::AccessDenied
  rescue_from CanCan::AccessDenied do |exception|
    respond_to do |format|
      format.html { redirect_to root_path, alert: exception.message }
      format.json { render json: { error: exception.message }, status: :forbidden }
    end
  end

  private

  # Override Devise helper to use current_user
  def current_ability
    @current_ability ||= Ability.new(current_user)
  end

  # Redirect after sign in
  def after_sign_in_path_for(resource)
    if resource.admin?
      admin_dashboard_path
    else
      user_dashboard_path
    end
  end
end
