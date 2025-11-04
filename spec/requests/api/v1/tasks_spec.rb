require 'rails_helper'

RSpec.describe 'Api::V1::Tasks', type: :request do
  let(:admin) { create(:user, :admin) }
  let(:manager) { create(:user, :manager) }
  let(:member) { create(:user, :member) }
  let(:headers) { { 'Authorization' => "Bearer #{user.email}" } }
  let(:user) { admin }

  describe 'GET /api/v1/tasks' do
    let!(:task1) { create(:task, creator: member) }
    let!(:task2) { create(:task, creator: admin) }

    context 'as admin' do
      let(:user) { admin }

      it 'returns all tasks' do
        get '/api/v1/tasks', headers: headers
        expect(response).to have_http_status(:ok)
      end
    end

    context 'as member' do
      let(:user) { member }

      it 'returns only own tasks' do
        get '/api/v1/tasks', headers: headers
        expect(response).to have_http_status(:ok)
      end
    end

    context 'without authentication' do
      it 'returns unauthorized' do
        get '/api/v1/tasks'
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v1/tasks' do
    let(:valid_params) do
      {
        task: {
          title: 'New Task',
          description: 'Description',
          priority: 'high'
        }
      }
    end

    it 'creates a task' do
      post '/api/v1/tasks', params: valid_params, headers: headers
      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)['data']['attributes']['title']).to eq('New Task')
    end

    context 'with invalid params' do
      it 'returns error' do
        post '/api/v1/tasks', params: { task: { title: '' } }, headers: headers
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'GET /api/v1/tasks/:id' do
    let(:task) { create(:task, creator: member) }

    context 'as task creator' do
      let(:user) { member }

      it 'returns task' do
        get "/api/v1/tasks/#{task.id}", headers: headers
        expect(response).to have_http_status(:ok)
      end
    end

    context 'as admin' do
      let(:user) { admin }

      it 'returns task' do
        get "/api/v1/tasks/#{task.id}", headers: headers
        expect(response).to have_http_status(:ok)
      end
    end

    context 'as unauthorized member' do
      let(:user) { create(:user, :member) }

      it 'returns unauthorized' do
        get "/api/v1/tasks/#{task.id}", headers: headers
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v1/tasks/:id/complete' do
    let(:task) { create(:task, creator: member, status: :pending) }
    let(:user) { member }

    it 'completes the task' do
      post "/api/v1/tasks/#{task.id}/complete", headers: headers
      expect(response).to have_http_status(:ok)
      expect(task.reload.status).to eq('completed')
    end
  end

  describe 'GET /api/v1/tasks/dashboard' do
    let(:user) { admin }
    let!(:task1) { create(:task, creator: admin, status: :pending) }
    let!(:task2) { create(:task, creator: admin, status: :completed, completed_at: 1.day.ago) }
    let!(:task3) { create(:task, creator: admin, assignee: admin, status: :in_progress) }

    it 'returns dashboard stats' do
      get '/api/v1/tasks/dashboard', headers: headers
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['data']).to have_key('total_by_status')
      expect(json['data']).to have_key('overdue_count')
      expect(json['data']).to have_key('assigned_incomplete')
      expect(json['data']).to have_key('recent_activity')
    end
  end
end
