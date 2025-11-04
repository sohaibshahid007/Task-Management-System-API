# Custom Sidekiq middleware for enhanced logging and monitoring
module Middleware
  class SidekiqLoggingMiddleware
    # Server middleware signature (Sidekiq 8)
    def call(worker, job, queue)
      start_time = Time.current
      job_class = job["class"]
      job_id = job["jid"]

      Rails.logger.info "[Sidekiq] Starting job: #{job_class} (JID: #{job_id})"

      begin
        yield
        duration = Time.current - start_time
        Rails.logger.info "[Sidekiq] Completed job: #{job_class} (JID: #{job_id}) in #{duration.round(2)}s"
      rescue StandardError => e
        duration = Time.current - start_time
        Rails.logger.error "[Sidekiq] Failed job: #{job_class} (JID: #{job_id}) after #{duration.round(2)}s"
        Rails.logger.error "[Sidekiq] Error: #{e.class} - #{e.message}"
        raise # Re-raise to trigger Sidekiq retry mechanism
      end
    end
  end

  # Client middleware for logging job enqueueing (Sidekiq 8 signature)
  class SidekiqClientLoggingMiddleware
    def call(worker_class, job, queue, redis_pool)
      job_class = worker_class.to_s
      job_id = job["jid"]
      Rails.logger.info "[Sidekiq] Enqueuing job: #{job_class} (JID: #{job_id}) to queue: #{queue}"
      yield
    end
  end
end
