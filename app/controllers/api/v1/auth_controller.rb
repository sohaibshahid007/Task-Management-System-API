class Api::V1::AuthController < Api::BaseController
  skip_before_action :authenticate_user!, only: [:login, :signup, :password_reset]

  def login
    return unless validate_login_params!
    
    user = User.find_by(email: params[:email]&.downcase&.strip)
    
    unless user
      return render_error(
        code: 'INVALID_CREDENTIALS',
        message: I18n.t('auth.invalid_credentials'),
        details: {},
        status: :unauthorized
      )
    end

    if user.valid_password?(params[:password])
      render json: {
        user: UserSerializer.new(user).serializable_hash,
        token: user.email # Simplified token - use JWT in production
      }, status: :ok
    else
      render_error(
        code: 'INVALID_CREDENTIALS',
        message: I18n.t('auth.invalid_credentials'),
        details: {},
        status: :unauthorized
      )
    end
  rescue StandardError => e
    Rails.logger.error "Login error: #{e.class} - #{e.message}"
    render_error(
      code: 'INTERNAL_SERVER_ERROR',
      message: I18n.t('errors.unexpected_error'),
      details: {},
      status: :internal_server_error
    )
  end

  def signup
    return unless validate_signup_params!
    
    user = User.new(user_params)
    
    if user.save
      render json: {
        user: UserSerializer.new(user).serializable_hash,
        token: user.email
      }, status: :created
    else
      render_validation_error(
        message: I18n.t('auth.signup_failed'),
        errors: user.errors.full_messages
      )
    end
  rescue StandardError => e
    Rails.logger.error "Signup error: #{e.class} - #{e.message}"
    render_error(
      code: 'INTERNAL_SERVER_ERROR',
      message: I18n.t('errors.unexpected_error'),
      details: {},
      status: :internal_server_error
    )
  end

  def logout
    render json: { message: I18n.t('auth.logout_successful') }, status: :ok
  end

  def password_reset
    unless params[:email].present?
      return render_bad_request(
        message: I18n.t('auth.email_required'),
        details: { parameter: 'email' }
      )
    end

    user = User.find_by(email: params[:email]&.downcase&.strip)
    
    if user
      begin
        user.send_reset_password_instructions
        render json: { message: I18n.t('auth.password_reset_sent') }, status: :ok
      rescue StandardError => e
        Rails.logger.error "Password reset error: #{e.class} - #{e.message}"
        render_error(
          code: 'INTERNAL_SERVER_ERROR',
          message: I18n.t('auth.password_reset_failed'),
          details: {},
          status: :internal_server_error
        )
      end
    else
      # Don't reveal if user exists or not for security
      render json: { message: I18n.t('auth.password_reset_confirmation') }, status: :ok
    end
  end

  private

  def validate_login_params!
    errors = []
    errors << I18n.t('auth.email_required') if params[:email].blank?
    errors << I18n.t('auth.password_required') if params[:password].blank?
    
    if errors.any?
      render_bad_request(message: I18n.t('validations.missing_parameters'), details: { errors: errors })
      return false
    end
    true
  end

  def validate_signup_params!
    errors = []
    errors << I18n.t('auth.email_required') if params[:email].blank?
    errors << I18n.t('auth.password_required') if params[:password].blank?
    errors << I18n.t('auth.first_name_required') if params[:first_name].blank?
    errors << I18n.t('auth.last_name_required') if params[:last_name].blank?
    
    if params[:password].present? && params[:password].length < 6
      errors << I18n.t('auth.password_too_short')
    end
    
    if params[:password] != params[:password_confirmation]
      errors << I18n.t('auth.password_mismatch')
    end
    
    if errors.any?
      render_bad_request(message: I18n.t('validations.invalid_signup_parameters'), details: { errors: errors })
      return false
    end
    true
  end

  def user_params
    params.permit(:email, :password, :password_confirmation, :first_name, :last_name, :role)
  end
end

