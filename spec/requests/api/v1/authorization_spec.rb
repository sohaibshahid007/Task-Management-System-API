require 'rails_helper'

RSpec.describe 'Role-Based Authorization', type: :request do
  let(:admin) { create(:user, :admin, email: 'admin@example.com') }
  let(:manager) { create(:user, :manager, email: 'manager@example.com') }
  let(:member) { create(:user, :member, email: 'member@example.com') }
  let(:other_member) { create(:user, :member, email: 'other@example.com') }

  def auth_headers(user)
    { 'Authorization' => "Bearer #{user.email}" }
  end

  describe 'Task Permissions' do
    let!(:member_task) { create(:task, creator: member, title: 'Member Task') }
    let!(:other_task) { create(:task, creator: other_member, title: 'Other Task') }

    describe 'Create Tasks' do
      it 'allows admin to create tasks' do
        post '/api/v1/tasks',
          params: { task: { title: 'Admin Task', priority: 'high' } },
          headers: auth_headers(admin)

        expect(response).to have_http_status(:created)
      end

      it 'allows manager to create tasks' do
        post '/api/v1/tasks',
          params: { task: { title: 'Manager Task', priority: 'high' } },
          headers: auth_headers(manager)

        expect(response).to have_http_status(:created)
      end

      it 'allows member to create tasks' do
        post '/api/v1/tasks',
          params: { task: { title: 'Member Task', priority: 'high' } },
          headers: auth_headers(member)

        expect(response).to have_http_status(:created)
      end
    end

    describe 'Edit Own Tasks' do
      it 'allows admin to edit own tasks' do
        admin_task = create(:task, creator: admin)
        patch "/api/v1/tasks/#{admin_task.id}",
          params: { task: { title: 'Updated Title' } },
          headers: auth_headers(admin)

        expect(response).to have_http_status(:ok)
      end

      it 'allows manager to edit own tasks' do
        manager_task = create(:task, creator: manager)
        patch "/api/v1/tasks/#{manager_task.id}",
          params: { task: { title: 'Updated Title' } },
          headers: auth_headers(manager)

        expect(response).to have_http_status(:ok)
      end

      it 'allows member to edit own tasks' do
        patch "/api/v1/tasks/#{member_task.id}",
          params: { task: { title: 'Updated Title' } },
          headers: auth_headers(member)

        expect(response).to have_http_status(:ok)
      end
    end

    describe 'Edit Any Task' do
      it 'allows admin to edit any task' do
        patch "/api/v1/tasks/#{member_task.id}",
          params: { task: { title: 'Admin Updated' } },
          headers: auth_headers(admin)

        expect(response).to have_http_status(:ok)
      end

      it 'allows manager to edit any task' do
        patch "/api/v1/tasks/#{member_task.id}",
          params: { task: { title: 'Manager Updated' } },
          headers: auth_headers(manager)

        expect(response).to have_http_status(:ok)
      end

      it 'denies member to edit other tasks' do
        patch "/api/v1/tasks/#{other_task.id}",
          params: { task: { title: 'Unauthorized Update' } },
          headers: auth_headers(member)

        expect(response).to have_http_status(:unauthorized)
      end
    end

    describe 'Delete Any Task' do
      it 'allows admin to delete any task' do
        delete "/api/v1/tasks/#{member_task.id}", headers: auth_headers(admin)

        expect(response).to have_http_status(:ok)
      end

      it 'denies manager to delete tasks' do
        delete "/api/v1/tasks/#{member_task.id}", headers: auth_headers(manager)

        expect(response).to have_http_status(:unauthorized)
      end

      it 'denies member to delete tasks' do
        delete "/api/v1/tasks/#{member_task.id}", headers: auth_headers(member)

        expect(response).to have_http_status(:unauthorized)
      end
    end

    describe 'Assign Tasks' do
      let(:assignee) { create(:user, :member) }

      it 'allows admin to assign tasks' do
        post "/api/v1/tasks/#{member_task.id}/assign",
          params: { assignee_id: assignee.id },
          headers: auth_headers(admin)

        expect(response).to have_http_status(:ok)
      end

      it 'allows manager to assign tasks' do
        post "/api/v1/tasks/#{member_task.id}/assign",
          params: { assignee_id: assignee.id },
          headers: auth_headers(manager)

        expect(response).to have_http_status(:ok)
      end

      it 'denies member to assign tasks' do
        post "/api/v1/tasks/#{member_task.id}/assign",
          params: { assignee_id: assignee.id },
          headers: auth_headers(member)

        expect(response).to have_http_status(:unauthorized)
      end
    end

    describe 'View All Tasks' do
      it 'allows admin to view all tasks' do
        get '/api/v1/tasks', headers: auth_headers(admin)

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        task_ids = json['data'].map { |t| t['id'].to_i }
        expect(task_ids).to include(member_task.id, other_task.id)
      end

      it 'allows manager to view all tasks' do
        get '/api/v1/tasks', headers: auth_headers(manager)

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        task_ids = json['data'].map { |t| t['id'].to_i }
        expect(task_ids).to include(member_task.id, other_task.id)
      end

      it 'allows member to view only own tasks' do
        get '/api/v1/tasks', headers: auth_headers(member)

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        task_ids = json['data'].map { |t| t['id'].to_i }
        expect(task_ids).to include(member_task.id)
        expect(task_ids).not_to include(other_task.id)
      end
    end
  end

  describe 'User Permissions' do
    describe 'List Users' do
      it 'allows admin to list all users' do
        get '/api/v1/users', headers: auth_headers(admin)

        expect(response).to have_http_status(:ok)
      end

      it 'allows manager to list all users' do
        get '/api/v1/users', headers: auth_headers(manager)

        expect(response).to have_http_status(:ok)
      end

      it 'denies member to list users' do
        get '/api/v1/users', headers: auth_headers(member)

        expect(response).to have_http_status(:unauthorized)
      end
    end

    describe 'Create Users' do
      it 'allows admin to create users' do
        post '/api/v1/auth/signup',
          params: {
            email: 'newuser@example.com',
            password: 'password123',
            password_confirmation: 'password123',
            first_name: 'New',
            last_name: 'User',
            role: 'member'
          },
          headers: auth_headers(admin)

        expect(User.count).to be > 0
      end
    end

    describe 'Delete Users' do
      it 'allows admin to delete users' do
        delete "/api/v1/users/#{member.id}", headers: auth_headers(admin)

        expect(response).to have_http_status(:ok)
      end

      it 'denies manager to delete users' do
        delete "/api/v1/users/#{member.id}", headers: auth_headers(manager)

        expect(response).to have_http_status(:unauthorized)
      end

      it 'denies member to delete users' do
        delete "/api/v1/users/#{other_member.id}", headers: auth_headers(member)

        expect(response).to have_http_status(:unauthorized)
      end

      it 'prevents admin from deleting own account' do
        delete "/api/v1/users/#{admin.id}", headers: auth_headers(admin)

        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
