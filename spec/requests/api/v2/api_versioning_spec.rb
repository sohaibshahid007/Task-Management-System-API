require 'rails_helper'

RSpec.describe 'API Versioning - V2 (Breaking Changes)', type: :request do
  let(:admin) { create(:user, :admin) }
  let(:member) { create(:user, :member) }

  def auth_headers(user)
    { 'Authorization' => "Bearer #{user.email}" }
  end

  describe 'V2 API Breaking Changes' do
    let!(:task) do
      create(:task,
        creator: admin,
        assignee: member,
        title: 'Test Task',
        description: 'Test Description',
        status: :pending,
        priority: :high,
        due_date: 1.day.from_now
      )
    end

    describe 'camelCase Response Format' do
      it 'uses camelCase instead of snake_case for task attributes' do
        get "/api/v2/tasks/#{task.id}", headers: auth_headers(admin)

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)

        expect(json).to have_key('dueDate')
        expect(json).to have_key('completedAt')
        expect(json).to have_key('createdAt')
        expect(json).to have_key('updatedAt')

        expect(json).not_to have_key('due_date')
        expect(json).not_to have_key('completed_at')
      end

      it 'uses camelCase for nested user attributes' do
        get "/api/v2/tasks/#{task.id}", headers: auth_headers(admin)

        json = JSON.parse(response.body)
        expect(json['creator']).to have_key('fullName')
        expect(json['creator']).not_to have_key('full_name')

        expect(json['assignee']).to have_key('fullName')
        expect(json['assignee']).not_to have_key('full_name')
      end
    end

    describe 'V2 Endpoints' do
      it 'GET /api/v2/tasks exists' do
        get '/api/v2/tasks', headers: auth_headers(admin)
        expect(response).to have_http_status(:ok)
      end

      it 'GET /api/v2/tasks/:id exists' do
        get "/api/v2/tasks/#{task.id}", headers: auth_headers(admin)
        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        expect(json).to have_key('id')
        expect(json).to have_key('title')
      end

      it 'PATCH /api/v2/tasks/:id exists' do
        patch "/api/v2/tasks/#{task.id}",
          params: { task: { title: 'Updated' } },
          headers: auth_headers(admin)
        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        expect(json['title']).to eq('Updated')
      end

      it 'DELETE /api/v2/tasks/:id exists' do
        task_to_delete = create(:task, creator: admin)
        delete "/api/v2/tasks/#{task_to_delete.id}", headers: auth_headers(admin)
        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        expect(json).to have_key('message')
      end
    end

    describe 'V2 vs V1 Comparison' do
      it 'V1 returns snake_case format' do
        get "/api/v1/tasks/#{task.id}", headers: auth_headers(admin)

        json = JSON.parse(response.body)
        attributes = json['data']['attributes']

        expect(attributes).to have_key('due_date')
        expect(attributes).to have_key('created_at')
        expect(attributes).not_to have_key('dueDate')
      end

      it 'V2 returns camelCase format' do
        get "/api/v2/tasks/#{task.id}", headers: auth_headers(admin)

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)

        expect(json).to have_key('dueDate')
        expect(json).to have_key('createdAt')
        expect(json).to have_key('completedAt')
        expect(json).to have_key('updatedAt')
        expect(json).not_to have_key('due_date')
        expect(json).not_to have_key('created_at')
      end

      it 'demonstrates breaking change between versions' do
        get "/api/v1/tasks/#{task.id}", headers: auth_headers(admin)
        v1_json = JSON.parse(response.body)

        get "/api/v2/tasks/#{task.id}", headers: auth_headers(admin)
        v2_json = JSON.parse(response.body)

        expect(v1_json['data']['attributes']).to have_key('due_date')

        expect(v2_json).to have_key('dueDate')
        expect(v2_json).not_to have_key('due_date')
      end
    end

    describe 'V2 Filtering and Pagination' do
      before do
        Task.destroy_all
        15.times { create(:task, creator: admin, status: :pending) }
        5.times { create(:task, creator: admin, status: :completed) }
      end

      it 'supports filtering by status' do
        get '/api/v2/tasks',
          params: { status: 'pending' },
          headers: auth_headers(admin)

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json).to be_an(Array)
        expect(json.length).to be > 0
        expect(json.all? { |t| t['status'] == 'pending' }).to be true
      end

      it 'supports filtering by priority' do
        Task.destroy_all
        create(:task, creator: admin, priority: :high)
        get '/api/v2/tasks',
          params: { priority: 'high' },
          headers: auth_headers(admin)

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json.length).to be > 0
        expect(json.all? { |t| t['priority'] == 'high' }).to be true
      end

      it 'supports pagination' do
        Task.destroy_all
        10.times { create(:task, creator: admin) }
        get '/api/v2/tasks',
          params: { page: 1, per_page: 5 },
          headers: auth_headers(admin)

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json.length).to be <= 5
      end
    end

    describe 'V2 Error Responses' do
      it 'returns consistent error format (same as V1)' do
        get '/api/v2/tasks/99999', headers: auth_headers(admin)

        json = JSON.parse(response.body)
        expect(json).to have_key('error')
        expect(json['error']).to have_key('code')
        expect(json['error']).to have_key('message')
        expect(json['error']).to have_key('details')
      end

      it 'returns 401 for unauthorized requests' do
        get '/api/v2/tasks'
        expect(response).to have_http_status(:unauthorized)
      end

      it 'returns 404 for not found' do
        get '/api/v2/tasks/99999', headers: auth_headers(admin)
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
