# Custom error controller for API JSON error responses
# This handles 404 and 500 errors for API requests with proper JSON responses
class ErrorsController < ApplicationController
  # No authentication required for error pages

  # Handle 404 Not Found errors
  def not_found
    render_error(
      code: "NOT_FOUND",
      message: I18n.t("errors.resource_not_found"),
      details: { path: request.path },
      status: :not_found
    )
  end

  # Handle 500 Internal Server Error
  def internal_server_error
    render_error(
      code: "INTERNAL_SERVER_ERROR",
      message: I18n.t("errors.unexpected_error"),
      details: Rails.env.development? ? { error: "Internal server error" } : {},
      status: :internal_server_error
    )
  end

  # Handle 422 Unprocessable Entity
  def unprocessable_entity
    render_error(
      code: "UNPROCESSABLE_ENTITY",
      message: I18n.t("errors.validation_failed"),
      details: {},
      status: :unprocessable_entity
    )
  end

  private

  def render_error(code:, message:, details: {}, status:)
    render json: {
      error: {
        code: code,
        message: message,
        details: details
      }
    }, status: status
  end
end
