class ApplicationJob < ActiveJob::Base
  # Use Sidekiq as the queue adapter
  queue_adapter = :sidekiq
end
