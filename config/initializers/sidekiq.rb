# Load middleware files before configuring Sidekiq
require Rails.root.join("lib", "middleware", "sidekiq_logging_middleware")
require Rails.root.join("lib", "middleware", "sidekiq_error_tracking_middleware")

# Sidekiq configuration
Sidekiq.configure_server do |config|
  config.redis = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0") }

  # Configure queues with priorities
  # Higher priority queues are processed first
  config.poll_interval = 1

  # Custom middleware for logging and error tracking
  config.server_middleware do |chain|
    # Add custom logging middleware for enhanced job logging
    chain.add Middleware::SidekiqLoggingMiddleware

    # Add error tracking middleware for monitoring and debugging
    chain.add Middleware::SidekiqErrorTrackingMiddleware
  end
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0") }

  # Client middleware (runs when jobs are enqueued)
  # Note: Sidekiq 8 client middleware has different signature (worker_class, job, queue, redis_pool)
  config.client_middleware do |chain|
    # Add logging for job enqueueing
    chain.add Middleware::SidekiqClientLoggingMiddleware
  end
end
