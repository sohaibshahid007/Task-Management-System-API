# Performance Monitoring Concern
# Provides helper methods for controllers to track performance metrics
module PerformanceMonitoring
  extend ActiveSupport::Concern

  included do
    around_action :track_performance_metrics, if: -> { Rails.env.development? || Rails.env.test? }
  end

  private

  # Track performance metrics for controller actions
  def track_performance_metrics
    start_time = Time.current
    start_query_count = current_query_count
    
    yield
    
    duration = ((Time.current - start_time) * 1000).round(2)
    query_count = current_query_count - start_query_count
    
    # Log performance metrics for this action
    log_action_performance(
      controller: self.class.name,
      action: action_name,
      duration: duration,
      query_count: query_count
    )
  rescue StandardError => e
    Rails.logger.error "PerformanceMonitoring error: #{e.class} - #{e.message}"
    raise
  end

  def log_action_performance(controller:, action:, duration:, query_count:)
    # Log to Rails logger
    Rails.logger.info "[Controller Performance] #{controller}##{action} | " \
                      "Duration: #{duration}ms | Queries: #{query_count}"
    
    # Warn about slow actions
    if duration > 500 # > 500ms
      Rails.logger.warn "[Controller Performance] SLOW ACTION: #{controller}##{action} took #{duration}ms"
    end
    
    # Warn about high query count
    if query_count > 10
      Rails.logger.warn "[Controller Performance] HIGH QUERY COUNT: #{controller}##{action} executed #{query_count} queries"
    end
  end

  def current_query_count
    # Get current query count from Active Record connection
    ActiveRecord::Base.connection.query_cache.size
  rescue StandardError
    0
  end
end

