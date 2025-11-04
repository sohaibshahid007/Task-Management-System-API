class TaskNotificationJob
  include Sidekiq::Job
  sidekiq_options queue: :default, retry: 3

  def perform(task_id, action)
    unless task_id.present?
      Rails.logger.error "TaskNotificationJob failed: Task ID is required"
      return
    end

    unless action.present?
      Rails.logger.error "TaskNotificationJob failed: Action is required"
      return
    end

    task = Task.find_by(id: task_id)
    unless task
      Rails.logger.error "TaskNotificationJob failed: Task not found with id #{task_id}"
      return
    end

    begin
      case action.to_s
      when "created", "assigned"
        send_assignment_notification(task) if task.assignee.present?
      when "completed"
        send_completion_notification(task)
      else
        Rails.logger.warn "TaskNotificationJob: Unknown action '#{action}' for task #{task_id}"
      end
    rescue StandardError => e
      Rails.logger.error "TaskNotificationJob error for task #{task_id}: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      raise # Re-raise to trigger Sidekiq retry
    end
  end

  private

  def send_assignment_notification(task)
    unless task.assignee.present?
      Rails.logger.warn "TaskNotificationJob: Cannot send assignment notification - no assignee for task #{task.id}"
      return
    end

    TaskMailer.task_assigned(task).deliver_now
  rescue StandardError => e
    Rails.logger.error "Failed to send assignment notification for task #{task.id}: #{e.message}"
    raise
  end

  def send_completion_notification(task)
    unless task.creator.present?
      Rails.logger.warn "TaskNotificationJob: Cannot send completion notification - no creator for task #{task.id}"
      return
    end

    TaskMailer.task_completed(task).deliver_now
  rescue StandardError => e
    Rails.logger.error "Failed to send completion notification for task #{task.id}: #{e.message}"
    raise
  end
end
