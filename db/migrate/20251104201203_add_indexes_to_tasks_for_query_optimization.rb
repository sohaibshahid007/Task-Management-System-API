class AddIndexesToTasksForQueryOptimization < ActiveRecord::Migration[8.1]
  def change
    # Composite index for common query: tasks assigned to a user with status filter
    # Used in: assigned_to scope, dashboard queries
    add_index :tasks, [ :assignee_id, :status ], name: 'index_tasks_on_assignee_id_and_status', if_not_exists: true

    # Composite index for common query: tasks created by a user
    # Used in: created_by scope
    add_index :tasks, [ :creator_id, :status ], name: 'index_tasks_on_creator_id_and_status', if_not_exists: true

    # Composite index for overdue queries: due_date with status
    # Used in: overdue scope
    add_index :tasks, [ :due_date, :status ], name: 'index_tasks_on_due_date_and_status', if_not_exists: true

    # Composite index for priority-based filtering with status
    # Used in: filtering by priority and status together
    add_index :tasks, [ :priority, :status ], name: 'index_tasks_on_priority_and_status', if_not_exists: true

    # Index for completed_at for archival queries
    # Used in: TaskArchivalJob (completed tasks older than 30 days)
    add_index :tasks, [ :status, :completed_at ], name: 'index_tasks_on_status_and_completed_at', if_not_exists: true
  end
end
