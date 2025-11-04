class ApplicationController < ActionController::API
  include Pundit::Authorization
  include ErrorHandler
end
