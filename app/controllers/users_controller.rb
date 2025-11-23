class UsersController < ApplicationController
  # Load and authorize resource will be handled by ApplicationController
  # Admin can manage :all
  # User and Developer cannot destroy User

  before_action :set_user, only: [ :show, :edit, :update, :destroy, :soft_delete ]

  def index
    @users = User.active.order(created_at: :desc)
  end

  def show
  end

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    @user.provider = "local"

    if @user.save
      redirect_to users_path, notice: "User created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @user.update(user_params)
      redirect_to @user, notice: "User updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @user.destroy
    redirect_to users_path, notice: "User deleted successfully."
  end

  def soft_delete
    @user.soft_delete!
    redirect_to users_path, notice: "User soft deleted successfully."
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    # Admin can set role, user cannot set role
    if current_user&.admin?
      params.require(:user).permit(:email, :name, :password, :password_confirmation, :role, :avatar)
    else
      params.require(:user).permit(:email, :name, :password, :password_confirmation, :avatar)
    end
  end
end
