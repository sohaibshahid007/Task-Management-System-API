class Api::V1::TasksController < Api::BaseController
  before_action :set_task, only: [:show, :update, :destroy, :assign, :complete, :export]

  # GET /api/v1/tasks
  def index
    tasks = filtered_tasks
    tasks = paginated_tasks(tasks)
    
    render json: TaskSerializer.new(tasks.includes(:creator, :assignee)).serializable_hash
  end

  # GET /api/v1/tasks/:id
  def show
    return unless @task # Guard clause if set_task failed
    
    authorize @task
    render json: TaskSerializer.new(@task).serializable_hash
  end

  # POST /api/v1/tasks
  def create
    authorize Task
    
    validate_task_params!
    
    result = TaskCreationService.call(user: current_user, params: params)
    
    if result.success?
      render json: TaskSerializer.new(result.data).serializable_hash, status: :created
    else
      render_validation_error(
        message: I18n.t('tasks.creation_failed'),
        errors: result.errors
      )
    end
  rescue ArgumentError => e
    render_bad_request(message: e.message)
  end

  # PATCH/PUT /api/v1/tasks/:id
  def update
    return unless @task # Guard clause if set_task failed
    
    authorize @task
    
    validate_task_params!
    
    if @task.update(task_params)
      render json: TaskSerializer.new(@task).serializable_hash
    else
      render_validation_error(
        message: I18n.t('tasks.update_failed'),
        errors: @task.errors.full_messages
      )
    end
  rescue ArgumentError => e
    render_bad_request(message: e.message)
  end

  # DELETE /api/v1/tasks/:id
  def destroy
    return unless @task # Guard clause if set_task failed
    
    authorize @task
    
    if @task.destroy
      render json: { message: I18n.t('tasks.deleted_successfully') }, status: :ok
    else
      render_validation_error(
        message: I18n.t('tasks.deletion_failed'),
        errors: @task.errors.full_messages
      )
    end
  end

  # POST /api/v1/tasks/:id/assign
  def assign
    return unless @task # Guard clause if set_task failed
    
    authorize @task, :assign?
    
    validate_assignee_id!
    
    assignee = User.find_by(id: params[:assignee_id])
    unless assignee
      return render_not_found(resource: 'Assignee')
    end
    
    result = TaskAssignmentService.call(
      task: @task,
      assignee: assignee,
      assigned_by: current_user
    )
    
    if result.success?
      render json: TaskSerializer.new(result.data).serializable_hash
    else
      render_validation_error(
        message: I18n.t('tasks.assignment_failed'),
        errors: result.errors
      )
    end
  rescue ArgumentError => e
    render_bad_request(message: e.message)
  end

  # POST /api/v1/tasks/:id/complete
  def complete
    return unless @task # Guard clause if set_task failed
    
    authorize @task, :complete?
    
    result = TaskCompletionService.call(task: @task, user: current_user)
    
    if result.success?
      render json: TaskSerializer.new(result.data).serializable_hash
    else
      render_validation_error(
        message: I18n.t('tasks.completion_failed'),
        errors: result.errors
      )
    end
  end

  # GET /api/v1/tasks/dashboard
  def dashboard
    authorize Task, :index?
    
    base_tasks = policy_scope(Task).includes(:creator, :assignee)
    
    render json: {
      data: {
        total_by_status: total_by_status(base_tasks),
        overdue_count: overdue_count(base_tasks),
        assigned_incomplete: assigned_incomplete_tasks(base_tasks),
        recent_activity: recent_activity_tasks(base_tasks)
      }
    }
  end

  # GET /api/v1/tasks/overdue
  def overdue
    authorize Task, :index?
    
    tasks = policy_scope(Task).overdue.includes(:creator, :assignee)
    render json: TaskSerializer.new(tasks).serializable_hash
  end

  # POST /api/v1/tasks/:id/export
  def export
    return unless @task # Guard clause if set_task failed
    
    authorize @task, :show?
    
    # Enqueue export job with error handling
    # In test mode, Sidekiq fake mode handles job enqueueing
    if Rails.env.test?
      DataExportJob.perform_async(current_user.id)
    else
      begin
        DataExportJob.perform_async(current_user.id)
      rescue Redis::CannotConnectError, Redis::TimeoutError, Errno::ECONNREFUSED, Redis::ConnectionError => e
        # Log Redis connection failure
        Rails.logger.warn "TasksController: Failed to enqueue export job (Redis connection error): #{e.class} - #{e.message}"
        return render_error(
          code: 'SERVICE_UNAVAILABLE',
          message: I18n.t('tasks.export_service_unavailable'),
          details: Rails.env.development? ? { error: e.message, class: e.class.name } : {},
          status: :service_unavailable
        )
      rescue => e
        # Log other errors with more details in development
        Rails.logger.error "TasksController: Failed to enqueue export job: #{e.class} - #{e.message}"
        Rails.logger.error e.backtrace.first(5).join("\n") if Rails.env.development?
        return render_error(
          code: 'EXPORT_FAILED',
          message: I18n.t('tasks.export_failed'),
          details: Rails.env.development? ? { error: e.message, class: e.class.name } : {},
          status: :internal_server_error
        )
      end
    end
    
    render json: { message: I18n.t('tasks.export_queued') }, status: :accepted
  end

  private

  # Validates task parameters are present
  def validate_task_params!
    unless params[:task].present? || params[:title].present?
      raise ArgumentError, I18n.t('tasks.parameters_required')
    end
  end

  # Validates assignee_id is present
  def validate_assignee_id!
    unless params[:assignee_id].present?
      return render_bad_request(
        message: I18n.t('validations.assignee_id_required'),
        details: { parameter: 'assignee_id' }
      )
    end
  end

  # Applies filters to tasks based on query parameters
  def filtered_tasks
    tasks = policy_scope(Task)
    tasks = tasks.by_status(params[:status]) if params[:status].present?
    tasks = tasks.by_priority(params[:priority]) if params[:priority].present?
    tasks = tasks.assigned_to(current_user) if params[:assigned_to_me] == 'true'
    tasks = tasks.created_by(current_user) if params[:created_by_me] == 'true'
    tasks
  end

  # Paginates tasks with validated parameters
  def paginated_tasks(tasks)
    page = [params[:page]&.to_i || 1, 1].max
    per_page = [[params[:per_page]&.to_i || 20, 1].max, 100].min # Max 100 per page
    tasks.page(page).per(per_page)
  end

  # Dashboard helper methods for optimized queries
  
  # Returns total tasks count grouped by status (efficient aggregation)
  def total_by_status(tasks)
    tasks.group(:status).count
  end

  # Returns count of overdue tasks (efficient count query)
  def overdue_count(tasks)
    tasks.overdue.count
  end

  # Returns user's assigned incomplete tasks with creator info (no N+1)
  def assigned_incomplete_tasks(tasks)
    query = tasks.assigned_to(current_user)
                  .where.not(status: :completed)
                  .includes(:creator)
    TaskSerializer.new(query).serializable_hash
  end

  # Returns recent activity - last 10 tasks with associations (no N+1)
  def recent_activity_tasks(tasks)
    query = tasks.recent
                 .limit(10)
                 .includes(:creator, :assignee)
    TaskSerializer.new(query).serializable_hash
  end

  # Sets @task from params[:id] with proper error handling
  def set_task
    unless params[:id].present?
      render_bad_request(
        message: I18n.t('tasks.id_required'),
        details: { parameter: 'id' }
      )
      return
    end
    
    @task = Task.find_by(id: params[:id])
    unless @task
      render_not_found(resource: 'Task')
      return
    end
  end

  # Strong parameters for task creation/update
  def task_params
    params.require(:task).permit(:title, :description, :status, :priority, :due_date, :assignee_id)
  rescue ActionController::ParameterMissing
    params.permit(:title, :description, :status, :priority, :due_date, :assignee_id)
  end
end

