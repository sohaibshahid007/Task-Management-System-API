require 'rails_helper'

RSpec.describe 'Routes Configuration', type: :routing do
  describe 'API Versioning' do
    describe 'V1 API routes' do
      it 'routes GET /api/v1/tasks to tasks#index' do
        expect(get: '/api/v1/tasks').to route_to('api/v1/tasks#index')
      end

      it 'routes POST /api/v1/tasks to tasks#create' do
        expect(post: '/api/v1/tasks').to route_to('api/v1/tasks#create')
      end

      it 'routes GET /api/v1/tasks/:id to tasks#show' do
        expect(get: '/api/v1/tasks/1').to route_to('api/v1/tasks#show', id: '1')
      end

      it 'routes PATCH /api/v1/tasks/:id to tasks#update' do
        expect(patch: '/api/v1/tasks/1').to route_to('api/v1/tasks#update', id: '1')
      end

      it 'routes DELETE /api/v1/tasks/:id to tasks#destroy' do
        expect(delete: '/api/v1/tasks/1').to route_to('api/v1/tasks#destroy', id: '1')
      end
    end

    describe 'V2 API routes' do
      it 'routes GET /api/v2/tasks to v2/tasks#index' do
        expect(get: '/api/v2/tasks').to route_to('api/v2/tasks#index')
      end

      it 'routes GET /api/v2/tasks/:id to v2/tasks#show' do
        expect(get: '/api/v2/tasks/1').to route_to('api/v2/tasks#show', id: '1')
      end
    end
  end

  describe 'Nested Resources' do
    it 'routes GET /api/v1/tasks/:task_id/comments to comments#index' do
      expect(get: '/api/v1/tasks/1/comments').to route_to(
        'api/v1/comments#index',
        task_id: '1'
      )
    end

    it 'routes POST /api/v1/tasks/:task_id/comments to comments#create' do
      expect(post: '/api/v1/tasks/1/comments').to route_to(
        'api/v1/comments#create',
        task_id: '1'
      )
    end
  end

  describe 'Shallow Nesting' do
    it 'routes DELETE /api/v1/comments/:id to comments#destroy (shallow)' do
      expect(delete: '/api/v1/comments/1').to route_to(
        'api/v1/comments#destroy',
        id: '1'
      )
    end

    it 'does not require task_id for comment destroy (shallow)' do
      route_path = Rails.application.routes.url_helpers.api_v1_comment_path(1)
      expect(route_path).not_to include('task_id')
      expect(route_path).to eq('/api/v1/comments/1')
    end
  end

  describe 'Member Routes' do
    it 'routes POST /api/v1/tasks/:id/assign to tasks#assign' do
      expect(post: '/api/v1/tasks/1/assign').to route_to(
        'api/v1/tasks#assign',
        id: '1'
      )
    end

    it 'routes POST /api/v1/tasks/:id/complete to tasks#complete' do
      expect(post: '/api/v1/tasks/1/complete').to route_to(
        'api/v1/tasks#complete',
        id: '1'
      )
    end

    it 'routes POST /api/v1/tasks/:id/export to tasks#export' do
      expect(post: '/api/v1/tasks/1/export').to route_to(
        'api/v1/tasks#export',
        id: '1'
      )
    end
  end

  describe 'Collection Routes' do
    it 'routes GET /api/v1/tasks/dashboard to tasks#dashboard' do
      expect(get: '/api/v1/tasks/dashboard').to route_to('api/v1/tasks#dashboard')
    end

    it 'routes GET /api/v1/tasks/overdue to tasks#overdue' do
      expect(get: '/api/v1/tasks/overdue').to route_to('api/v1/tasks#overdue')
    end
  end

  describe 'Authentication Routes' do
    it 'routes POST /api/v1/auth/login to auth#login' do
      expect(post: '/api/v1/auth/login').to route_to('api/v1/auth#login')
    end

    it 'routes POST /api/v1/auth/signup to auth#signup' do
      expect(post: '/api/v1/auth/signup').to route_to('api/v1/auth#signup')
    end

    it 'routes POST /api/v1/auth/logout to auth#logout' do
      expect(post: '/api/v1/auth/logout').to route_to('api/v1/auth#logout')
    end

    it 'routes POST /api/v1/auth/password/reset to auth#password_reset' do
      expect(post: '/api/v1/auth/password/reset').to route_to('api/v1/auth#password_reset')
    end
  end

  describe 'User Routes' do
    it 'routes GET /api/v1/users to users#index' do
      expect(get: '/api/v1/users').to route_to('api/v1/users#index')
    end

    it 'routes GET /api/v1/users/:id to users#show' do
      expect(get: '/api/v1/users/1').to route_to('api/v1/users#show', id: '1')
    end

    it 'routes PATCH /api/v1/users/:id to users#update' do
      expect(patch: '/api/v1/users/1').to route_to('api/v1/users#update', id: '1')
    end

    it 'routes DELETE /api/v1/users/:id to users#destroy' do
      expect(delete: '/api/v1/users/1').to route_to('api/v1/users#destroy', id: '1')
    end
  end

  describe 'Health Check' do
    it 'routes GET /up to rails/health#show' do
      expect(get: '/up').to route_to('rails/health#show')
    end
  end

  describe 'Route Concerns' do
    it 'defines commentable concern in routes file' do
      routes_file = File.read(Rails.root.join('config', 'routes.rb'))
      expect(routes_file).to include('concern :commentable')
      expect(routes_file).to include('concern :assignable')
      expect(routes_file).to include('concern :completable')
    end
  end

  describe 'RESTful Design' do
    it 'uses RESTful conventions for tasks' do
      expect(get: '/api/v1/tasks').to be_routable
      expect(post: '/api/v1/tasks').to be_routable
      expect(get: '/api/v1/tasks/1').to be_routable
      expect(patch: '/api/v1/tasks/1').to be_routable
      expect(put: '/api/v1/tasks/1').to be_routable
      expect(delete: '/api/v1/tasks/1').to be_routable
    end

    it 'uses RESTful conventions for users' do
      expect(get: '/api/v1/users').to be_routable
      expect(get: '/api/v1/users/1').to be_routable
      expect(patch: '/api/v1/users/1').to be_routable
      expect(put: '/api/v1/users/1').to be_routable
      expect(delete: '/api/v1/users/1').to be_routable
    end
  end
end
