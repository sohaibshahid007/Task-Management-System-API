# V2 API with camelCase response format (breaking change from v1)
class Api::V2::TasksController < Api::BaseController
  before_action :set_task, only: [:show, :update, :destroy]

  def index
    authorize Task
    
    tasks = policy_scope(Task).includes(:creator, :assignee)
    tasks = tasks.by_status(params[:status]) if params[:status].present?
    tasks = tasks.by_priority(params[:priority]) if params[:priority].present?
    
    page = [params[:page]&.to_i || 1, 1].max
    per_page = [[params[:per_page]&.to_i || 20, 1].max, 100].min
    tasks = tasks.page(page).per(per_page)
    
    # V2 uses camelCase instead of snake_case
    render json: tasks.map { |task| camel_case_task(task) }
  end

  def show
    return unless @task # Guard clause if set_task failed
    
    authorize @task
    render json: camel_case_task(@task)
  end

  def update
    return unless @task # Guard clause if set_task failed
    
    authorize @task
    
    if @task.update(task_params)
      render json: camel_case_task(@task.reload)
    else
      render_validation_error(
        message: I18n.t('tasks.update_failed'),
        errors: @task.errors.full_messages
      )
    end
  end

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

  private

  def set_task
    unless params[:id].present?
      render_bad_request(
        message: I18n.t('tasks.id_required'),
        details: { parameter: 'id' }
      )
      return
    end
    
    @task = Task.includes(:creator, :assignee).find_by(id: params[:id])
    unless @task
      render_not_found(resource: 'Task')
      return
    end
  end

  def task_params
    params.require(:task).permit(:title, :description, :status, :priority, :due_date, :assignee_id)
  rescue ActionController::ParameterMissing
    params.permit(:title, :description, :status, :priority, :due_date, :assignee_id)
  end

  def camel_case_task(task)
    {
      id: task.id,
      title: task.title,
      description: task.description,
      status: task.status,
      priority: task.priority,
      dueDate: task.due_date,
      completedAt: task.completed_at,
      createdAt: task.created_at,
      updatedAt: task.updated_at,
      creator: {
        id: task.creator.id,
        fullName: task.creator.full_name,
        email: task.creator.email
      },
      assignee: task.assignee.present? ? {
        id: task.assignee.id,
        fullName: task.assignee.full_name,
        email: task.assignee.email
      } : nil
    }
  end
end
