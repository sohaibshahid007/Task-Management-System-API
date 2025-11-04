class TaskCreationService < ApplicationService
  def initialize(user:, params:)
    @user = user
    @params = params
  end

  def call
    validate_user!
    params_hash = task_params
    validate_params!(params_hash)

    task = @user.created_tasks.build(params_hash)

    if task.save
      if task.assignee.present?
        TaskNotificationJob.perform_async(task.id, "created")
      end

      success(task)
    else
      failure(format_errors(task.errors))
    end
  rescue StandardError => e
    Rails.logger.error "TaskCreationService error: #{e.class} - #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    failure([ I18n.t("services.task_creation.unexpected_error") ])
  end

  private

  def validate_user!
    unless @user.is_a?(User)
      raise ArgumentError, I18n.t("services.task_creation.invalid_user")
    end
  end

  def validate_params!(params_hash)
    errors = []
    errors << I18n.t("services.task_creation.title_required") if params_hash[:title].blank?

    if params_hash[:priority].present?
      valid_priorities = Task.priorities.keys
      unless valid_priorities.include?(params_hash[:priority].to_s)
        errors << I18n.t("services.task_creation.invalid_priority", priorities: valid_priorities.join(", "))
      end
    end

    if params_hash[:assignee_id].present?
      assignee = User.find_by(id: params_hash[:assignee_id])
      unless assignee
        errors << I18n.t("services.task_creation.assignee_not_found")
      end
    end

    raise ArgumentError, errors.join(", ") if errors.any?
  end

  def task_params
    task_params = @params[:task] || @params

    unless task_params
      raise ArgumentError, I18n.t("services.task_creation.parameters_required")
    end

    permitted = task_params.is_a?(ActionController::Parameters) ?
      task_params.permit(:title, :description, :status, :priority, :due_date, :assignee_id) :
      task_params.slice(:title, :description, :status, :priority, :due_date, :assignee_id)

    result = permitted.to_h.symbolize_keys
    result[:status] ||= "pending"
    result
  rescue ActionController::ParameterMissing => e
    raise ArgumentError, I18n.t("services.task_creation.missing_parameter", param: e.param)
  end

  def format_errors(errors)
    errors.is_a?(ActiveModel::Errors) ? errors.full_messages : Array(errors)
  end
end
