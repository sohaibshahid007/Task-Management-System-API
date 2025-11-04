require 'rails_helper'

RSpec.describe 'Authentication', type: :request do
  describe 'POST /api/v1/auth/signup' do
    context 'with valid parameters' do
      let(:valid_params) do
        {
          email: 'newuser@example.com',
          password: 'password123',
          password_confirmation: 'password123',
          first_name: 'John',
          last_name: 'Doe'
        }
      end

      it 'creates a new user with member role by default' do
        expect {
          post '/api/v1/auth/signup', params: valid_params
        }.to change(User, :count).by(1)

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json['user']['data']['attributes']['email']).to eq('newuser@example.com')
        expect(json['user']['data']['attributes']['role']).to eq('member')
        expect(json).to have_key('token')
      end

      it 'creates user with admin role if specified' do
        valid_params[:role] = 'admin'
        post '/api/v1/auth/signup', params: valid_params

        expect(response).to have_http_status(:created)
        user = User.find_by(email: 'newuser@example.com')
        expect(user.role).to eq('admin')
      end
    end

    context 'with invalid parameters' do
      it 'returns error for missing email' do
        post '/api/v1/auth/signup', params: {
          password: 'password123',
          password_confirmation: 'password123',
          first_name: 'John',
          last_name: 'Doe'
        }

        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)
        expect(json['error']['code']).to eq('BAD_REQUEST')
      end

      it 'returns error for invalid email format' do
        post '/api/v1/auth/signup', params: {
          email: 'invalid-email',
          password: 'password123',
          password_confirmation: 'password123',
          first_name: 'John',
          last_name: 'Doe'
        }

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns error for password mismatch' do
        post '/api/v1/auth/signup', params: {
          email: 'test@example.com',
          password: 'password123',
          password_confirmation: 'different',
          first_name: 'John',
          last_name: 'Doe'
        }

        expect(response).to have_http_status(:bad_request)
      end

      it 'returns error for short password' do
        post '/api/v1/auth/signup', params: {
          email: 'test@example.com',
          password: '12345',
          password_confirmation: '12345',
          first_name: 'John',
          last_name: 'Doe'
        }

        expect(response).to have_http_status(:bad_request)
      end
    end
  end

  describe 'POST /api/v1/auth/login' do
    let(:user) { create(:user, email: 'test@example.com', password: 'password123', first_name: 'Test', last_name: 'User') }

    context 'with valid credentials' do
      it 'returns authentication token' do
        post '/api/v1/auth/login', params: {
          email: 'test@example.com',
          password: 'password123'
        }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json).to have_key('token')
        expect(json).to have_key('user')
        expect(json['token']).to eq(user.email)
      end

      it 'handles email case insensitivity' do
        post '/api/v1/auth/login', params: {
          email: 'TEST@EXAMPLE.COM',
          password: 'password123'
        }

        expect(response).to have_http_status(:ok)
      end
    end

    context 'with invalid credentials' do
      it 'returns error for wrong password' do
        post '/api/v1/auth/login', params: {
          email: 'test@example.com',
          password: 'wrongpassword'
        }

        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body)
        expect(json['error']['code']).to eq('INVALID_CREDENTIALS')
      end

      it 'returns error for non-existent user' do
        post '/api/v1/auth/login', params: {
          email: 'nonexistent@example.com',
          password: 'password123'
        }

        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body)
        expect(json['error']['code']).to eq('INVALID_CREDENTIALS')
      end

      it 'returns error for missing email' do
        post '/api/v1/auth/login', params: { password: 'password123' }

        expect(response).to have_http_status(:bad_request)
      end

      it 'returns error for missing password' do
        post '/api/v1/auth/login', params: { email: 'test@example.com' }

        expect(response).to have_http_status(:bad_request)
      end
    end
  end

  describe 'POST /api/v1/auth/password/reset' do
    let(:user) { create(:user, email: 'test@example.com') }

    it 'sends password reset instructions for existing user' do
      expect {
        post '/api/v1/auth/password/reset', params: { email: 'test@example.com' }
      }.to change { ActionMailer::Base.deliveries.count }.by(1)

      expect(response).to have_http_status(:ok)
    end

    it 'returns success even for non-existent user (security)' do
      post '/api/v1/auth/password/reset', params: { email: 'nonexistent@example.com' }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['message']).to include('If an account exists')
    end

    it 'returns error for missing email' do
      post '/api/v1/auth/password/reset', params: {}

      expect(response).to have_http_status(:bad_request)
    end
  end

  describe 'POST /api/v1/auth/logout' do
    let(:user) { create(:user, email: 'test@example.com') }
    let(:headers) { { 'Authorization' => "Bearer #{user.email}" } }

    it 'logs out successfully' do
      post '/api/v1/auth/logout', headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['message']).to eq('Logged out successfully')
    end
  end

  describe 'Token-based authentication' do
    let(:user) { create(:user, email: 'test@example.com') }
    let(:headers) { { 'Authorization' => "Bearer #{user.email}" } }

    it 'authenticates user with valid token' do
      get '/api/v1/users', headers: headers

      expect(response).to have_http_status(:ok)
    end

    it 'rejects request without token' do
      get '/api/v1/users'

      expect(response).to have_http_status(:unauthorized)
      json = JSON.parse(response.body)
      expect(json['error']['code']).to eq('UNAUTHORIZED')
    end

    it 'rejects request with invalid token format' do
      invalid_headers = { 'Authorization' => 'InvalidFormat token' }
      get '/api/v1/users', headers: invalid_headers

      expect(response).to have_http_status(:unauthorized)
    end

    it 'rejects request with non-existent user token' do
      invalid_headers = { 'Authorization' => 'Bearer nonexistent@example.com' }
      get '/api/v1/users', headers: invalid_headers

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
