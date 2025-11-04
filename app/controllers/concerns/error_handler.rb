module ErrorHandler
  extend ActiveSupport::Concern

  included do
    rescue_from ActiveRecord::RecordInvalid, with: :handle_record_invalid
    rescue_from ActiveRecord::RecordNotFound, with: :handle_record_not_found
    rescue_from Pundit::NotAuthorizedError, with: :handle_unauthorized
    rescue_from ActionController::ParameterMissing, with: :handle_parameter_missing
    rescue_from ActionDispatch::Http::Parameters::ParseError, with: :handle_json_parse_error
    rescue_from StandardError, with: :handle_standard_error
  end

  private

  def handle_record_invalid(exception)
    render_error(
      code: "VALIDATION_ERROR",
      message: I18n.t("errors.validation_failed"),
      details: exception.record.errors.full_messages,
      status: :unprocessable_entity
    )
  end

  def handle_record_not_found(exception)
    render_error(
      code: "NOT_FOUND",
      message: I18n.t("errors.resource_not_found"),
      details: { resource: exception.model },
      status: :not_found
    )
  end

  def handle_unauthorized(exception)
    render_error(
      code: "UNAUTHORIZED",
      message: I18n.t("errors.unauthorized"),
      details: { policy: exception.policy&.class&.name },
      status: :unauthorized
    )
  end

  def handle_parameter_missing(exception)
    render_error(
      code: "MISSING_PARAMETER",
      message: I18n.t("errors.missing_parameter"),
      details: { parameter: exception.param },
      status: :bad_request
    )
  end

  def handle_json_parse_error(exception)
    render_error(
      code: "BAD_REQUEST",
      message: I18n.t("errors.invalid_json"),
      details: { error: "Invalid JSON in request body. Please check the format." },
      status: :bad_request
    )
  end

  def handle_standard_error(exception)
    Rails.logger.error "Unhandled error: #{exception.class} - #{exception.message}"
    Rails.logger.error exception.backtrace.join("\n")

    if exception.is_a?(Pundit::Error)
      Rails.logger.error "Pundit error not caught by specific handler: #{exception.class}"
      return handle_unauthorized(exception) if exception.is_a?(Pundit::NotAuthorizedError)
    end

    render_error(
      code: "INTERNAL_SERVER_ERROR",
      message: I18n.t("errors.unexpected_error"),
      details: Rails.env.development? || Rails.env.test? ? { error: exception.message, class: exception.class.name, backtrace: exception.backtrace.first(5) } : {},
      status: :internal_server_error
    )
  end

  def render_error(code:, message:, details: {}, status:)
    render json: {
      error: {
        code: code,
        message: message,
        details: details
      }
    }, status: status
  end

  def render_not_found(resource: "Resource")
    render_error(
      code: "NOT_FOUND",
      message: I18n.t("errors.resource_not_found", resource: resource),
      details: {},
      status: :not_found
    )
  end

  def render_unauthorized(message: nil)
    message ||= I18n.t("errors.unauthorized")
    render_error(
      code: "UNAUTHORIZED",
      message: message,
      details: {},
      status: :unauthorized
    )
  end

  def render_bad_request(message: nil, details: {})
    message ||= I18n.t("errors.invalid_request")
    render_error(
      code: "BAD_REQUEST",
      message: message,
      details: details,
      status: :bad_request
    )
  end

  def render_validation_error(message: nil, errors: [])
    message ||= I18n.t("errors.validation_failed")
    render_error(
      code: "VALIDATION_ERROR",
      message: message,
      details: { errors: errors },
      status: :unprocessable_entity
    )
  end
end
