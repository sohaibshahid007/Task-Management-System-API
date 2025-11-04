# Base service class for consistent result objects
class Application
  Result = Struct.new(:success?, :data, :errors, keyword_init: true)

  def self.call(*args, **kwargs)
    new(*args, **kwargs).call
  end

  def success(data = nil)
    Result.new(success?: true, data: data, errors: [])
  end

  def failure(errors)
    errors = Array(errors) unless errors.is_a?(Hash)
    Result.new(success?: false, data: nil, errors: errors)
  end
end
