class TaskQuery < Application
  def initialize(user:, params:)
    @user = user
    @params = params
  end

  def call
    tasks = build_base_query
    tasks = apply_status_filter(tasks)
    tasks = apply_priority_filter(tasks)
    tasks = apply_user_filters(tasks)
    tasks = eager_load_associations(tasks)

    success(tasks)
  end

  private

  def build_base_query
    TaskPolicy::Scope.new(@user, Task).resolve
  end

  def apply_status_filter(tasks)
    return tasks unless @params[:status].present?
    tasks.by_status(@params[:status])
  end

  def apply_priority_filter(tasks)
    return tasks unless @params[:priority].present?
    tasks.by_priority(@params[:priority])
  end

  def apply_user_filters(tasks)
    tasks = tasks.assigned_to(@user) if @params[:assigned_to_me] == "true"
    tasks = tasks.created_by(@user) if @params[:created_by_me] == "true"
    tasks
  end

  def eager_load_associations(tasks)
    tasks.includes(:creator, :assignee)
  end
end
