# Custom Sidekiq middleware for error tracking and metrics
module Middleware
  class SidekiqErrorTrackingMiddleware
    def call(worker, job, queue)
      yield
    rescue StandardError => e
      # Track error metrics
      track_error(worker, job, queue, e)
      raise # Re-raise to trigger Sidekiq retry mechanism
    end

    private

    def track_error(worker, job, queue, error)
      # Log error details for monitoring
      error_details = {
        job_class: job["class"],
        job_id: job["jid"],
        queue: queue,
        error_class: error.class.name,
        error_message: error.message,
        retry_count: job["retry_count"] || 0,
        failed_at: Time.current
      }

      Rails.logger.error "[Sidekiq Error Tracking] #{error_details.to_json}"
    end
  end
end
