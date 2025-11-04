class TaskCompletion < Application
  def initialize(task:, user:)
    @task = task
    @user = user
  end

  def call
    validate_task!
    validate_user!

    if @task.completed?
      return failure([ I18n.t("services.task_completion.already_completed") ])
    end

    if @task.update(status: :completed, completed_at: Time.current)
      if Rails.env.test?
        TaskNotificationJob.perform_async(@task.id, "completed")
      else
        begin
          TaskNotificationJob.perform_async(@task.id, "completed")
        rescue Redis::CannotConnectError, Redis::TimeoutError, Errno::ECONNREFUSED, Redis::ConnectionError => e
          Rails.logger.warn "TaskCompletion: Failed to enqueue notification job (Redis connection error): #{e.class} - #{e.message}"
        rescue => e
          Rails.logger.warn "TaskCompletion: Failed to enqueue notification job: #{e.class} - #{e.message}"
          Rails.logger.debug e.backtrace.first(3).join("\n") if Rails.env.development?
        end
      end

      success(@task)
    else
      failure(format_errors(@task.errors))
    end
  rescue ArgumentError => e
    failure([ e.message ])
  rescue StandardError => e
    Rails.logger.error "TaskCompletion error: #{e.class} - #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    failure([ I18n.t("services.task_completion.unexpected_error") ])
  end

  private

  def validate_task!
    unless @task.is_a?(Task)
      raise ArgumentError, I18n.t("services.task_completion.invalid_task")
    end
  end

  def validate_user!
    unless @user.is_a?(User)
      raise ArgumentError, I18n.t("services.task_completion.invalid_user")
    end
  end

  def format_errors(errors)
    errors.is_a?(ActiveModel::Errors) ? errors.full_messages : Array(errors)
  end
end
