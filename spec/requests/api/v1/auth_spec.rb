require 'rails_helper'

RSpec.describe 'Api::V1::Auth', type: :request do
  describe 'POST /api/v1/auth/login' do
    let(:user) { create(:user, email: 'test@example.com', password: 'password123') }

    it 'returns token on successful login' do
      post '/api/v1/auth/login', params: { email: 'test@example.com', password: 'password123' }
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).to have_key('token')
    end

    it 'returns error on invalid credentials' do
      post '/api/v1/auth/login', params: { email: 'test@example.com', password: 'wrong' }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'POST /api/v1/auth/signup' do
    it 'creates a new user' do
      post '/api/v1/auth/signup', params: {
        email: 'newuser@example.com',
        password: 'password123',
        password_confirmation: 'password123',
        first_name: 'John',
        last_name: 'Doe'
      }
      expect(response).to have_http_status(:created)
      expect(User.count).to eq(1)
    end

    it 'returns error on invalid params' do
      post '/api/v1/auth/signup', params: { email: 'invalid' }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end

