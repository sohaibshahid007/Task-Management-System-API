class UserSerializer
  include JSONAPI::Serializer

  attributes :email, :first_name, :last_name, :role, :created_at, :updated_at

  attribute :full_name do |user|
    user.full_name
  end
end
