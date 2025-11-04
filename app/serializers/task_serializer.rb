class TaskSerializer
  include JSONAPI::Serializer

  attributes :title, :description, :status, :priority, :due_date, :completed_at, :created_at, :updated_at

  belongs_to :creator, serializer: UserSerializer
  belongs_to :assignee, serializer: UserSerializer, optional: true

  attribute :overdue do |task|
    task.overdue?
  end
end
