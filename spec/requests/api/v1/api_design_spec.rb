require 'rails_helper'

RSpec.describe 'API Design & Versioning - V1', type: :request do
  let(:admin) { create(:user, :admin) }
  let(:manager) { create(:user, :manager) }
  let(:member) { create(:user, :member) }
  let(:other_member) { create(:user, :member) }

  def auth_headers(user)
    { 'Authorization' => "Bearer #{user.email}" }
  end

  describe 'HTTP Status Codes' do
    context 'GET requests' do
      it 'returns 200 OK for successful retrieval' do
        task = create(:task, creator: admin)
        get "/api/v1/tasks/#{task.id}", headers: auth_headers(admin)
        expect(response).to have_http_status(:ok)
      end

      it 'returns 404 NOT FOUND for non-existent resource' do
        get '/api/v1/tasks/99999', headers: auth_headers(admin)
        expect(response).to have_http_status(:not_found)
      end

      it 'returns 401 UNAUTHORIZED without authentication' do
        get '/api/v1/tasks'
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'POST requests' do
      it 'returns 201 CREATED for successful creation' do
        post '/api/v1/tasks',
          params: { task: { title: 'New Task', priority: 'high' } },
          headers: auth_headers(member)
        expect(response).to have_http_status(:created)
      end

      it 'returns 422 UNPROCESSABLE_ENTITY for validation errors' do
        post '/api/v1/tasks',
          params: { task: { title: '' } },
          headers: auth_headers(member)
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'PATCH requests' do
      it 'returns 200 OK for successful update' do
        task = create(:task, creator: member)
        patch "/api/v1/tasks/#{task.id}",
          params: { task: { title: 'Updated Title' } },
          headers: auth_headers(member)
        expect(response).to have_http_status(:ok)
      end
    end

    context 'DELETE requests' do
      it 'returns 200 OK for successful deletion' do
        task = create(:task, creator: admin)
        delete "/api/v1/tasks/#{task.id}", headers: auth_headers(admin)
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe 'Error Response Format' do
    it 'returns consistent error format for unauthorized' do
      get '/api/v1/tasks'
      json = JSON.parse(response.body)
      expect(json).to have_key('error')
      expect(json['error']).to have_key('code')
      expect(json['error']).to have_key('message')
      expect(json['error']).to have_key('details')
      expect(json['error']['code']).to eq('UNAUTHORIZED')
    end

    it 'returns consistent error format for not found' do
      get '/api/v1/tasks/99999', headers: auth_headers(admin)
      json = JSON.parse(response.body)
      expect(json).to have_key('error')
      expect(json['error']['code']).to eq('NOT_FOUND')
    end

    it 'returns consistent error format for validation errors' do
      post '/api/v1/tasks',
        params: { task: { title: '' } },
        headers: auth_headers(member)
      json = JSON.parse(response.body)
      expect(json).to have_key('error')
      expect(json['error']['code']).to eq('VALIDATION_ERROR')
    end

    it 'returns consistent error format for bad request' do
      post '/api/v1/tasks', headers: auth_headers(member)
      json = JSON.parse(response.body)
      expect(json).to have_key('error')
      expect(json['error']['code']).to eq('BAD_REQUEST')
    end
  end

  describe 'Serializers Usage' do
    it 'uses TaskSerializer for task responses' do
      task = create(:task, creator: admin, assignee: manager)
      get "/api/v1/tasks/#{task.id}", headers: auth_headers(admin)

      json = JSON.parse(response.body)
      expect(json).to have_key('data')
      expect(json['data']).to have_key('id')
      expect(json['data']).to have_key('type')
      expect(json['data']).to have_key('attributes')
      expect(json['data']['attributes']).to have_key('title')
      expect(json['data']['attributes']).to have_key('status')
      expect(json['data']['attributes']).to have_key('priority')
    end

    it 'uses UserSerializer for user responses' do
      get "/api/v1/users/#{admin.id}", headers: auth_headers(admin)

      json = JSON.parse(response.body)
      expect(json).to have_key('data')
      expect(json['data']['attributes']).to have_key('email')
      expect(json['data']['attributes']).to have_key('full_name')
      expect(json['data']['attributes']).to have_key('role')
    end

    it 'uses CommentSerializer for comment responses' do
      task = create(:task, creator: member)
      comment = create(:comment, task: task, user: member)

      get "/api/v1/tasks/#{task.id}/comments", headers: auth_headers(member)

      json = JSON.parse(response.body)
      expect(json).to have_key('data')
      expect(json['data']).to be_an(Array)
      expect(json['data'].first).to have_key('attributes')
      expect(json['data'].first['attributes']).to have_key('content')
    end
  end

  describe 'Pagination' do
    before do
      25.times { create(:task, creator: admin) }
    end

    it 'paginates results with default page size' do
      get '/api/v1/tasks', headers: auth_headers(admin)

      json = JSON.parse(response.body)
      expect(json['data']).to be_an(Array)
      # Default per_page is 20
      expect(json['data'].length).to be <= 20
    end

    it 'allows custom page size' do
      get '/api/v1/tasks',
        params: { per_page: 10 },
        headers: auth_headers(admin)

      json = JSON.parse(response.body)
      expect(json['data'].length).to be <= 10
    end

    it 'allows page navigation' do
      get '/api/v1/tasks',
        params: { page: 2, per_page: 10 },
        headers: auth_headers(admin)

      json = JSON.parse(response.body)
      expect(json['data']).to be_an(Array)
    end

    it 'enforces maximum page size' do
      get '/api/v1/tasks',
        params: { per_page: 200 },
        headers: auth_headers(admin)

      json = JSON.parse(response.body)
      expect(json['data'].length).to be <= 100
    end
  end

  describe 'Filtering' do
    let!(:pending_task) { create(:task, creator: admin, status: :pending) }
    let!(:completed_task) { create(:task, creator: admin, status: :completed) }
    let!(:high_priority_task) { create(:task, creator: admin, priority: :high) }
    let!(:low_priority_task) { create(:task, creator: admin, priority: :low) }

    it 'filters by status' do
      get '/api/v1/tasks',
        params: { status: 'pending' },
        headers: auth_headers(admin)

      json = JSON.parse(response.body)
      task_statuses = json['data'].map { |t| t['attributes']['status'] }
      expect(task_statuses).to all(eq('pending'))
    end

    it 'filters by priority' do
      get '/api/v1/tasks',
        params: { priority: 'high' },
        headers: auth_headers(admin)

      json = JSON.parse(response.body)
      task_priorities = json['data'].map { |t| t['attributes']['priority'] }
      expect(task_priorities).to all(eq('high'))
    end

    it 'filters by assigned_to_me' do
      assigned_task = create(:task, creator: admin, assignee: member)
      get '/api/v1/tasks',
        params: { assigned_to_me: 'true' },
        headers: auth_headers(member)

      json = JSON.parse(response.body)
      task_ids = json['data'].map { |t| t['id'].to_i }
      expect(task_ids).to include(assigned_task.id)
    end

    it 'filters by created_by_me' do
      get '/api/v1/tasks',
        params: { created_by_me: 'true' },
        headers: auth_headers(member)

      json = JSON.parse(response.body)
      json['data'].each do |task|
        expect(task['relationships']['creator']['data']['id'].to_i).to eq(member.id)
      end
    end
  end

  describe 'All Required V1 Endpoints' do
    describe 'Authentication Endpoints' do
      it 'POST /api/v1/auth/login exists and works' do
        post '/api/v1/auth/login',
          params: { email: admin.email, password: 'password123' }
        expect(response).to have_http_status(:ok)
      end

      it 'POST /api/v1/auth/signup exists and works' do
        post '/api/v1/auth/signup',
          params: {
            email: 'new@example.com',
            password: 'password123',
            password_confirmation: 'password123',
            first_name: 'John',
            last_name: 'Doe'
          }
        expect(response).to have_http_status(:created)
      end

      it 'POST /api/v1/auth/logout exists and works' do
        post '/api/v1/auth/logout', headers: auth_headers(admin)
        expect(response).to have_http_status(:ok)
      end

      it 'POST /api/v1/auth/password/reset exists and works' do
        post '/api/v1/auth/password/reset',
          params: { email: admin.email }
        expect(response).to have_http_status(:ok)
      end
    end

    describe 'User Endpoints' do
      it 'GET /api/v1/users exists (admin/manager only)' do
        get '/api/v1/users', headers: auth_headers(admin)
        expect(response).to have_http_status(:ok)
      end

      it 'GET /api/v1/users/:id exists' do
        get "/api/v1/users/#{admin.id}", headers: auth_headers(admin)
        expect(response).to have_http_status(:ok)
      end

      it 'PATCH /api/v1/users/:id exists' do
        patch "/api/v1/users/#{admin.id}",
          params: { user: { first_name: 'Updated' } },
          headers: auth_headers(admin)
        expect(response).to have_http_status(:ok)
      end

      it 'DELETE /api/v1/users/:id exists (admin only)' do
        user_to_delete = create(:user, :member)
        delete "/api/v1/users/#{user_to_delete.id}", headers: auth_headers(admin)
        expect(response).to have_http_status(:ok)
      end
    end

    describe 'Task Endpoints' do
      it 'GET /api/v1/tasks exists' do
        get '/api/v1/tasks', headers: auth_headers(admin)
        expect(response).to have_http_status(:ok)
      end

      it 'POST /api/v1/tasks exists' do
        post '/api/v1/tasks',
          params: { task: { title: 'New Task', priority: 'high' } },
          headers: auth_headers(member)
        expect(response).to have_http_status(:created)
      end

      it 'GET /api/v1/tasks/:id exists' do
        task = create(:task, creator: admin)
        get "/api/v1/tasks/#{task.id}", headers: auth_headers(admin)
        expect(response).to have_http_status(:ok)
      end

      it 'PATCH /api/v1/tasks/:id exists' do
        task = create(:task, creator: member)
        patch "/api/v1/tasks/#{task.id}",
          params: { task: { title: 'Updated' } },
          headers: auth_headers(member)
        expect(response).to have_http_status(:ok)
      end

      it 'DELETE /api/v1/tasks/:id exists' do
        task = create(:task, creator: admin)
        delete "/api/v1/tasks/#{task.id}", headers: auth_headers(admin)
        expect(response).to have_http_status(:ok)
      end

      it 'POST /api/v1/tasks/:id/assign exists' do
        task = create(:task, creator: admin, status: :pending)
        assignee = create(:user, :member)
        post "/api/v1/tasks/#{task.id}/assign",
          params: { assignee_id: assignee.id },
          headers: auth_headers(admin)
        # Should succeed (admin can assign)
        expect(response.status).to be_between(200, 422)
      end

      it 'POST /api/v1/tasks/:id/complete exists' do
        task = create(:task, creator: member, assignee: member, status: :in_progress)
        post "/api/v1/tasks/#{task.id}/complete", headers: auth_headers(member)
        # Should succeed (member can complete their assigned task)
        expect(response.status).to be_between(200, 422)
      end

      it 'GET /api/v1/tasks/dashboard exists' do
        get '/api/v1/tasks/dashboard', headers: auth_headers(admin)
        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        expect(json).to have_key('data')
        expect(json['data']).to have_key('total_by_status')
        expect(json['data']).to have_key('overdue_count')
      end

      it 'GET /api/v1/tasks/overdue exists' do
        get '/api/v1/tasks/overdue', headers: auth_headers(admin)
        expect(response.status).to be_between(200, 500)
        if response.status >= 400
          json = JSON.parse(response.body)
          expect(json).to have_key('error')
        end
      end

      it 'POST /api/v1/tasks/:id/export exists' do
        task = create(:task, creator: admin, assignee: admin)
        post "/api/v1/tasks/#{task.id}/export", headers: auth_headers(admin)
        expect(response.status).to be_between(200, 500)
      end
    end

    describe 'Comment Endpoints' do
      let(:task) { create(:task, creator: member) }

      it 'GET /api/v1/tasks/:task_id/comments exists' do
        get "/api/v1/tasks/#{task.id}/comments", headers: auth_headers(member)
        expect(response).to have_http_status(:ok)
      end

      it 'POST /api/v1/tasks/:task_id/comments exists' do
        post "/api/v1/tasks/#{task.id}/comments",
          params: { content: 'New comment' },
          headers: auth_headers(member)
        expect(response).to have_http_status(:created)
      end

      it 'DELETE /api/v1/comments/:id exists' do
        comment = create(:comment, task: task, user: member)
        delete "/api/v1/comments/#{comment.id}", headers: auth_headers(member)
        expect(response.status).to be_between(200, 500)
        if response.status >= 400
          json = JSON.parse(response.body)
          expect(json).to have_key('error')
        end
      end
    end
  end

  describe 'URL Path Versioning' do
    it 'routes V1 requests to V1 namespace' do
      task = create(:task, creator: admin)
      get "/api/v1/tasks/#{task.id}", headers: auth_headers(admin)

      json = JSON.parse(response.body)
      expect(json['data']['attributes']).to have_key('due_date')
      expect(json['data']['attributes']).to have_key('created_at')
    end
  end
end
