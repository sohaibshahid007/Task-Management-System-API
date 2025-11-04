class Api::V1::UsersController < Api::BaseController
  before_action :set_user, only: [:show, :update, :destroy]

  def index
    authorize User
    
    users = policy_scope(User).all
    render json: UserSerializer.new(users).serializable_hash
  end

  def show
    authorize @user
    render json: UserSerializer.new(@user).serializable_hash
  end

  def update
    authorize @user
    
    unless params[:user].present? || params[:first_name].present? || params[:last_name].present? || params[:email].present?
      return render_bad_request(
        message: I18n.t('users.parameters_required'),
        details: { parameter: 'user' }
      )
    end
    
    if @user.update(user_params)
      render json: UserSerializer.new(@user).serializable_hash
    else
      render_validation_error(
        message: I18n.t('users.update_failed'),
        errors: @user.errors.full_messages
      )
    end
  rescue StandardError => e
    Rails.logger.error "User update error: #{e.class} - #{e.message}"
    render_error(
      code: 'INTERNAL_SERVER_ERROR',
      message: I18n.t('errors.unexpected_error'),
      details: {},
      status: :internal_server_error
    )
  end

  def destroy
    authorize @user
    
    if @user == current_user
      return render_error(
        code: 'FORBIDDEN',
        message: I18n.t('users.cannot_delete_own_account'),
        details: {},
        status: :forbidden
      )
    end
    
    if @user.destroy
      render json: { message: I18n.t('users.deleted_successfully') }, status: :ok
    else
      render_validation_error(
        message: I18n.t('users.deletion_failed'),
        errors: @user.errors.full_messages
      )
    end
  rescue StandardError => e
    Rails.logger.error "User deletion error: #{e.class} - #{e.message}"
    render_error(
      code: 'INTERNAL_SERVER_ERROR',
      message: I18n.t('errors.unexpected_error'),
      details: {},
      status: :internal_server_error
    )
  end

  private

  def set_user
    unless params[:id].present?
      return render_bad_request(
        message: I18n.t('users.id_required'),
        details: { parameter: 'id' }
      )
    end
    
    @user = User.find_by(id: params[:id])
    unless @user
      render_not_found(resource: 'User')
    end
  end

  def user_params
    params.permit(:first_name, :last_name, :email, :role)
  end
end

