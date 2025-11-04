class Api::BaseController < ApplicationController
  include PerformanceMonitoring
  before_action :authenticate_user!

  private

  def current_user
    @current_user ||= authenticate_with_token
  end

  def authenticate_user!
    unless current_user
      render_error(
        code: "UNAUTHORIZED",
        message: I18n.t("auth.authentication_required"),
        details: {},
        status: :unauthorized
      )
      return false
    end
    true
  end

  def authenticate_with_token
    return nil unless request.headers["Authorization"].present?

    begin
      auth_header = request.headers["Authorization"]
      unless auth_header.start_with?("Bearer ")
        Rails.logger.warn "Invalid authorization header format"
        return nil
      end

      token = auth_header.split(" ").last
      return nil if token.blank?

      User.find_by(email: token&.downcase&.strip)
    rescue StandardError => e
      Rails.logger.error "Authentication error: #{e.class} - #{e.message}"
      nil
    end
  end
end
