class CommentSerializer
  include JSONAPI::Serializer

  attributes :content, :created_at, :updated_at

  belongs_to :user, serializer: UserSerializer
  belongs_to :task, serializer: TaskSerializer, optional: true
end
