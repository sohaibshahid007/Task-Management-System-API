class TaskArchivalJob
  include Sidekiq::Job
  sidekiq_options queue: :low_priority, retry: 3

  def perform
    begin
      old_completed_tasks = Task.where(status: :completed)
                                .where("completed_at < ?", 30.days.ago)

      count = 0
      errors = []

      old_completed_tasks.find_each do |task|
        if task.update(status: :archived)
          count += 1
        else
          errors << "Failed to archive task #{task.id}: #{task.errors.full_messages.join(', ')}"
        end
      end

      Rails.logger.info "TaskArchivalJob: Archived #{count} tasks"
      Rails.logger.warn "TaskArchivalJob: Encountered #{errors.count} errors" if errors.any?
      errors.each { |error| Rails.logger.error error }
    rescue StandardError => e
      Rails.logger.error "TaskArchivalJob failed: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      raise # Re-raise to trigger Sidekiq retry
    end
  end
end
