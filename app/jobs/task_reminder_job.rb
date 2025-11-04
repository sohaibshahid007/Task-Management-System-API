class TaskReminderJob
  include Sidekiq::Job
  sidekiq_options queue: :notifications, retry: 5

  def perform
    begin
      due_tomorrow = Task.where("due_date BETWEEN ? AND ?",
                                1.day.from_now.beginning_of_day,
                                1.day.from_now.end_of_day)
                         .where.not(status: :completed)
                         .includes(:assignee, :creator)

      sent_count = 0
      error_count = 0

      due_tomorrow.find_each do |task|
        if task.assignee.present?
          begin
            TaskMailer.task_reminder(task).deliver_now
            sent_count += 1
          rescue StandardError => e
            error_count += 1
            Rails.logger.error "Failed to send reminder for task #{task.id}: #{e.message}"
          end
        end
      end

      Rails.logger.info "TaskReminderJob: Sent #{sent_count} reminders, #{error_count} errors"
    rescue StandardError => e
      Rails.logger.error "TaskReminderJob failed: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      raise # Re-raise to trigger Sidekiq retry
    end
  end
end
