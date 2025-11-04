class TaskAssignmentService < ApplicationService
  def initialize(task:, assignee:, assigned_by:)
    @task = task
    @assignee = assignee
    @assigned_by = assigned_by
  end

  def call
    validate_inputs!

    unless authorized?
      return failure([ I18n.t("services.task_assignment.unauthorized") ])
    end

    unless @assignee.present?
      return failure([ I18n.t("services.task_assignment.assignee_not_found") ])
    end

    if @task.assignee_id == @assignee.id
      return failure([ I18n.t("services.task_assignment.already_assigned") ])
    end

    if @task.update(assignee: @assignee)
      if Rails.env.test?
        TaskNotificationJob.perform_async(@task.id, "assigned")
      else
        begin
          TaskNotificationJob.perform_async(@task.id, "assigned")
        rescue Redis::CannotConnectError, Redis::TimeoutError, Errno::ECONNREFUSED, Redis::ConnectionError => e
          Rails.logger.warn "TaskAssignmentService: Failed to enqueue notification job (Redis connection error): #{e.class} - #{e.message}"
        rescue => e
          Rails.logger.warn "TaskAssignmentService: Failed to enqueue notification job: #{e.class} - #{e.message}"
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
    Rails.logger.error "TaskAssignmentService error: #{e.class} - #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    failure([ I18n.t("services.task_assignment.unexpected_error") ])
  end

  private

  def validate_inputs!
    unless @task.is_a?(Task)
      raise ArgumentError, I18n.t("services.task_assignment.invalid_task")
    end

    unless @assignee.is_a?(User) || @assignee.nil?
      raise ArgumentError, I18n.t("services.task_assignment.invalid_assignee")
    end

    unless @assigned_by.is_a?(User)
      raise ArgumentError, I18n.t("services.task_assignment.invalid_user")
    end
  end

  def authorized?
    @assigned_by.admin? || @assigned_by.manager?
  end

  def format_errors(errors)
    errors.is_a?(ActiveModel::Errors) ? errors.full_messages : Array(errors)
  end
end
