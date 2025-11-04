class Api::V1::TasksController < Api::BaseController
  before_action :set_task, only: [ :show, :update, :destroy, :assign, :complete, :export ]

  def index
    result = TaskQuery.call(user: current_user, params: params)

    if result.success?
      tasks = apply_pagination(result.data)
      render_task_collection(tasks)
    else
      render_error(
        code: "QUERY_FAILED",
        message: I18n.t("errors.unexpected_error"),
        details: result.errors,
        status: :internal_server_error
      )
    end
  end

  def show
    return unless ensure_task_present

    authorize @task
    render_task(@task)
  end

  def create
    authorize Task
    validate_task_params!

    result = TaskCreation.call(user: current_user, params: params)
    handle_service_result(result, :creation_failed, :created)
  rescue ArgumentError => e
    render_bad_request(message: e.message)
  end

  def update
    return unless ensure_task_present

    authorize @task
    validate_task_params!

    if @task.update(task_params)
      render_task(@task)
    else
      render_validation_error(
        message: I18n.t("tasks.update_failed"),
        errors: @task.errors.full_messages
      )
    end
  rescue ArgumentError => e
    render_bad_request(message: e.message)
  end

  def destroy
    return unless ensure_task_present

    authorize @task

    if @task.destroy
      render_success_message(I18n.t("tasks.deleted_successfully"))
    else
      render_validation_error(
        message: I18n.t("tasks.deletion_failed"),
        errors: @task.errors.full_messages
      )
    end
  end

  def assign
    return unless ensure_task_present

    authorize @task, :assign?
    return unless validate_assignee_id!

    assignee = find_assignee
    return unless assignee

    result = TaskAssignment.call(
      task: @task,
      assignee: assignee,
      assigned_by: current_user
    )
    handle_service_result(result, :assignment_failed)
  rescue ArgumentError => e
    render_bad_request(message: e.message)
  end

  def complete
    return unless ensure_task_present

    authorize @task, :complete?

    result = TaskCompletion.call(task: @task, user: current_user)
    handle_service_result(result, :completion_failed)
  end

  def dashboard
    authorize Task, :index?

    dashboard_data = build_dashboard_data
    render_dashboard(dashboard_data)
  end

  def overdue
    authorize Task, :index?

    tasks = policy_scope(Task).overdue.includes(:creator, :assignee)
    render_task_collection(tasks)
  end

  def export
    return unless ensure_task_present

    authorize @task, :show?

    enqueue_export_job
    render_success_message(I18n.t("tasks.export_queued"), status: :accepted)
  rescue Redis::CannotConnectError, Redis::TimeoutError, Errno::ECONNREFUSED, Redis::ConnectionError => e
    handle_export_error(:export_service_unavailable, e, :service_unavailable)
  rescue StandardError => e
    handle_export_error(:export_failed, e, :internal_server_error)
  end

  private

  def apply_pagination(tasks)
    page = calculate_page_number
    per_page = calculate_per_page
    tasks.page(page).per(per_page)
  end

  def calculate_page_number
    [ params[:page]&.to_i || 1, 1 ].max
  end

  def calculate_per_page
    [ [ params[:per_page]&.to_i || 20, 1 ].max, 100 ].min
  end

  def build_dashboard_data
    base_tasks = policy_scope(Task).includes(:creator, :assignee)

    {
      total_by_status: calculate_total_by_status(base_tasks),
      overdue_count: calculate_overdue_count(base_tasks),
      assigned_incomplete: build_assigned_incomplete_tasks(base_tasks),
      recent_activity: build_recent_activity_tasks(base_tasks)
    }
  end

  def calculate_total_by_status(tasks)
    tasks.group(:status).count
  end

  def calculate_overdue_count(tasks)
    tasks.overdue.count
  end

  def build_assigned_incomplete_tasks(tasks)
    query = tasks.assigned_to(current_user)
                  .where.not(status: :completed)
                  .includes(:creator)
    serialize_task_collection(query)
  end

  def build_recent_activity_tasks(tasks)
    query = tasks.recent
                 .limit(10)
                 .includes(:creator, :assignee)
    serialize_task_collection(query)
  end


  def validate_task_params!
    unless params[:task].present? || params[:title].present?
      raise ArgumentError, I18n.t("tasks.parameters_required")
    end
  end

  def validate_assignee_id!
    return true if params[:assignee_id].present?

    render_bad_request(
      message: I18n.t("validations.assignee_id_required"),
      details: { parameter: "assignee_id" }
    )
    false
  end

  def set_task
    return false unless validate_task_id_present

    @task = Task.find_by(id: params[:id])
    return true if @task

    render_not_found(resource: "Task")
    false
  end

  def validate_task_id_present
    return true if params[:id].present?

    render_bad_request(
      message: I18n.t("tasks.id_required"),
      details: { parameter: "id" }
    )
    false
  end

  def ensure_task_present
    @task.present?
  end

  def find_assignee
    assignee = User.find_by(id: params[:assignee_id])
    return assignee if assignee

    render_not_found(resource: "Assignee")
    nil
  end

  def handle_service_result(result, error_key, success_status = :ok)
    if result.success?
      render_task(result.data, status: success_status)
    else
      render_validation_error(
        message: I18n.t("tasks.#{error_key}"),
        errors: result.errors
      )
    end
  end


  def enqueue_export_job
    if Rails.env.test?
      DataExportJob.perform_async(current_user.id)
    else
      DataExportJob.perform_async(current_user.id)
    end
  end

  def handle_export_error(error_key, exception, status)
    log_export_error(exception)
    render_error(
      code: error_key.to_s.upcase,
      message: I18n.t("tasks.#{error_key}"),
      details: build_error_details(exception),
      status: status
    )
  end

  def log_export_error(exception)
    if redis_connection_error?(exception)
      Rails.logger.warn "TasksController: Failed to enqueue export job (Redis connection error): #{exception.class} - #{exception.message}"
    else
      Rails.logger.error "TasksController: Failed to enqueue export job: #{exception.class} - #{exception.message}"
      Rails.logger.error exception.backtrace.first(5).join("\n") if Rails.env.development?
    end
  end

  def redis_connection_error?(exception)
    exception.is_a?(Redis::CannotConnectError) ||
      exception.is_a?(Redis::TimeoutError) ||
      exception.is_a?(Errno::ECONNREFUSED) ||
      exception.is_a?(Redis::ConnectionError)
  end

  def build_error_details(exception)
    return {} unless Rails.env.development?
    { error: exception.message, class: exception.class.name }
  end


  def render_task(task, status: :ok)
    render json: task, status: status
  end

  def render_task_collection(tasks)
    render json: TaskSerializer.new(tasks).serializable_hash
  end

  def serialize_task_collection(tasks)
    TaskSerializer.new(tasks).serializable_hash
  end

  def render_dashboard(data)
    render json: { data: data }
  end

  def render_success_message(message, status: :ok)
    render json: { message: message }, status: status
  end


  def task_params
    params.require(:task).permit(:title, :description, :status, :priority, :due_date, :assignee_id)
  rescue ActionController::ParameterMissing
    params.permit(:title, :description, :status, :priority, :due_date, :assignee_id)
  end
end
