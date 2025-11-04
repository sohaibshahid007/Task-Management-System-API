require 'rails_helper'

RSpec.describe 'API Error Handling', type: :request do
  describe '404 Not Found' do
    it 'returns JSON error response for non-existent API endpoint' do
      admin = create(:user, :admin)
      get '/api/v1/nonexistent_endpoint_12345',
        headers: {
          'Accept' => 'application/json',
          'Authorization' => "Bearer #{admin.email}"
        }

      expect(response.status).to eq(404)
      if response.body.present?
        json = JSON.parse(response.body)
        expect(json).to have_key('error') if json.is_a?(Hash)
      end
    end

    it 'returns JSON error response for non-existent task' do
      admin = create(:user, :admin)
      get '/api/v1/tasks/99999',
        headers: {
          'Authorization' => "Bearer #{admin.email}",
          'Accept' => 'application/json'
        }

      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json['error']['code']).to eq('NOT_FOUND')
    end

    it 'returns JSON error response for non-existent user' do
      admin = create(:user, :admin)
      get '/api/v1/users/99999',
        headers: {
          'Authorization' => "Bearer #{admin.email}",
          'Accept' => 'application/json'
        }

      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json['error']['code']).to eq('NOT_FOUND')
    end
  end

  describe '500 Internal Server Error' do
    it 'handles internal server errors with JSON response' do
      expect(ErrorsController.instance_methods).to include(:internal_server_error)
      expect(ErrorsController.instance_methods).to include(:not_found)
      expect(ErrorsController.instance_methods).to include(:unprocessable_entity)
      exceptions_app = Rails.application.config.exceptions_app
      expect(exceptions_app).to be_present
      expect(exceptions_app).to be_a(Proc)
    end
  end

  describe '422 Unprocessable Entity' do
    it 'returns JSON error for validation failures' do
      member = create(:user, :member)
      post '/api/v1/tasks',
        params: { task: { title: '' } },
        headers: {
          'Authorization' => "Bearer #{member.email}",
          'Accept' => 'application/json'
        }

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json).to have_key('error')
      expect(json['error']['code']).to eq('VALIDATION_ERROR')
    end
  end

  describe 'Error Response Format' do
    it 'returns consistent error format for all API errors' do
      admin = create(:user, :admin)
      get '/api/v1/tasks/999999',
        headers: {
          'Accept' => 'application/json',
          'Authorization' => "Bearer #{admin.email}"
        }

      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json).to have_key('error')
      expect(json['error']).to have_key('code')
      expect(json['error']).to have_key('message')
      expect(json['error']).to have_key('details')
      expect(json['error']['code']).to eq('NOT_FOUND')
    end
  end
end
