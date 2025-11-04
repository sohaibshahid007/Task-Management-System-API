require 'rails_helper'

RSpec.describe TaskCreationService do
  let(:user) { create(:user) }
  let(:params) { { title: 'New Task', description: 'Task description', priority: 'high' } }

  describe '.call' do
    context 'with valid parameters' do
      it 'creates a task successfully' do
        result = TaskCreationService.call(user: user, params: ActionController::Parameters.new(params))

        expect(result.success?).to be true
        expect(result.data).to be_a(Task)
        expect(result.data.title).to eq('New Task')
        expect(result.data.creator).to eq(user)
      end

      it 'returns consistent result object with success? method' do
        result = TaskCreationService.call(user: user, params: ActionController::Parameters.new(params))

        expect(result).to respond_to(:success?)
        expect(result).to respond_to(:data)
        expect(result).to respond_to(:errors)
        expect(result.success?).to be true
      end

      it 'sets default status to pending when not provided' do
        params_without_status = params.except(:status)
        result = TaskCreationService.call(user: user, params: ActionController::Parameters.new(params_without_status))

        expect(result.data.status).to eq('pending')
      end

      it 'allows setting custom status' do
        params_with_status = params.merge(status: 'in_progress')
        result = TaskCreationService.call(user: user, params: ActionController::Parameters.new(params_with_status))

        expect(result.data.status).to eq('in_progress')
      end

      it 'validates task parameters' do
        invalid_params = { title: '', description: 'Test' }
        result = TaskCreationService.call(user: user, params: ActionController::Parameters.new(invalid_params))

        expect(result.success?).to be false
        expect(result.errors).to be_present
        expect(result.errors).to be_an(Array)
      end

      it 'validates priority values' do
        invalid_params = params.merge(priority: 'invalid_priority')
        result = TaskCreationService.call(user: user, params: ActionController::Parameters.new(invalid_params))

        expect(result.success?).to be false
        expect(result.errors).to be_present
      end
    end

    context 'with invalid parameters' do
      it 'returns failure with errors for blank title' do
        invalid_params = { title: '' }
        result = TaskCreationService.call(user: user, params: ActionController::Parameters.new(invalid_params))

        expect(result.success?).to be false
        expect(result.errors).to be_present
        expect(result.data).to be_nil
      end

      it 'returns failure with errors for missing title' do
        invalid_params = { description: 'Test description' }
        result = TaskCreationService.call(user: user, params: ActionController::Parameters.new(invalid_params))

        expect(result.success?).to be false
        expect(result.errors).to be_present
      end

      it 'validates assignee exists' do
        invalid_params = params.merge(assignee_id: 99999)
        result = TaskCreationService.call(user: user, params: ActionController::Parameters.new(invalid_params))

        expect(result.success?).to be false
        expect(result.errors).to be_present
        expect(result.errors).to be_an(Array)
      end
    end

    context 'with assignee' do
      let(:assignee) { create(:user) }
      let(:params_with_assignee) { { task: params.merge(assignee_id: assignee.id) } }

      it 'assigns task to assignee' do
        result = TaskCreationService.call(user: user, params: ActionController::Parameters.new(params_with_assignee))

        expect(result.success?).to be true
        expect(result.data.assignee).to eq(assignee)
      end

      it 'sends notification to assignee via Sidekiq' do
        result = nil
        expect {
          result = TaskCreationService.call(user: user, params: ActionController::Parameters.new(params_with_assignee))
        }.to change { TaskNotificationJob.jobs.size }.by(1)

        job = TaskNotificationJob.jobs.last
        expect(job['args']).to eq([result.data.id, 'created'])
      end

      it 'does not send notification when no assignee' do
        expect {
          TaskCreationService.call(user: user, params: ActionController::Parameters.new(task: params))
        }.not_to change { TaskNotificationJob.jobs.size }
      end
    end

    context 'with nested params structure' do
      it 'handles nested task params' do
        nested_params = { task: params }
        result = TaskCreationService.call(user: user, params: ActionController::Parameters.new(nested_params))

        expect(result.success?).to be true
        expect(result.data.title).to eq('New Task')
      end

      it 'handles flat params structure' do
        result = TaskCreationService.call(user: user, params: ActionController::Parameters.new(params))

        expect(result.success?).to be true
        expect(result.data.title).to eq('New Task')
      end
    end

    context 'error handling' do
      it 'handles invalid user gracefully' do
        result = TaskCreationService.call(user: nil, params: ActionController::Parameters.new(params))

        expect(result.success?).to be false
        expect(result.errors).to be_present
      end

      it 'handles database errors gracefully' do
        allow_any_instance_of(Task).to receive(:save).and_raise(ActiveRecord::RecordInvalid.new(Task.new))

        result = TaskCreationService.call(user: user, params: ActionController::Parameters.new(params))

        expect(result.success?).to be false
        expect(result.errors).to be_present
      end
    end

    context 'service is testable in isolation' do
      it 'does not require database for validation' do
        invalid_params = { title: '' }
        result = TaskCreationService.call(user: user, params: ActionController::Parameters.new(invalid_params))

        expect(result.success?).to be false
      end
    end
  end
end

