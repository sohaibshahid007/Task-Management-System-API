require 'rails_helper'

RSpec.describe TaskCompletion do
  let(:task) { create(:task, status: :pending) }
  let(:user) { create(:user) }

  describe '.call' do
    context 'with valid task' do
      it 'marks task as completed' do
        result = TaskCompletion.call(task: task, user: user)

        expect(result.success?).to be true
        expect(task.reload.status).to eq('completed')
      end

      it 'sets completed_at timestamp' do
        freeze_time = Time.current
        travel_to freeze_time
        result = TaskCompletion.call(task: task, user: user)

        expect(result.success?).to be true
        expect(task.reload.completed_at).to be_within(1.second).of(freeze_time)
        travel_back
      end

      it 'returns consistent result object' do
        result = TaskCompletion.call(task: task, user: user)

        expect(result).to respond_to(:success?)
        expect(result).to respond_to(:data)
        expect(result).to respond_to(:errors)
        expect(result.success?).to be true
        expect(result.data).to be_a(Task)
      end

      it 'returns completed task in result data' do
        result = TaskCompletion.call(task: task, user: user)

        expect(result.data).to eq(task.reload)
        expect(result.data.status).to eq('completed')
      end

      it 'triggers notification to creator via Sidekiq' do
        expect {
          TaskCompletion.call(task: task, user: user)
        }.to change { TaskNotificationJob.jobs.size }.by(1)

        job = TaskNotificationJob.jobs.last
        expect(job['args']).to eq([task.id, 'completed'])
      end
    end

    context 'when task is already completed' do
      let(:completed_task) { create(:task, status: :completed, completed_at: 1.day.ago) }

      it 'returns failure with appropriate error message' do
        result = TaskCompletion.call(task: completed_task, user: user)

        expect(result.success?).to be false
        expect(result.errors).to include('Task is already completed')
        expect(result.data).to be_nil
      end

      it 'does not send notification for already completed task' do
        expect {
          TaskCompletion.call(task: completed_task, user: user)
        }.not_to change { TaskNotificationJob.jobs.size }
      end
    end

    context 'when task update fails' do
      before do
        task.errors.add(:base, 'Validation error')
        allow(task).to receive(:update).and_return(false)
        allow(task).to receive(:errors).and_return(task.errors)
      end

      it 'returns failure with errors' do
        result = TaskCompletion.call(task: task, user: user)

        expect(result.success?).to be false
        expect(result.errors).to be_present
        expect(result.errors).to be_an(Array)
      end

      it 'does not send notification when update fails' do
        expect {
          TaskCompletion.call(task: task, user: user)
        }.not_to change { TaskNotificationJob.jobs.size }
      end
    end

    context 'error handling' do
      it 'validates task parameter' do
        result = TaskCompletion.call(task: nil, user: user)

        expect(result.success?).to be false
        expect(result.errors).to be_present
      end

      it 'validates user parameter' do
        result = TaskCompletion.call(task: task, user: nil)

        expect(result.success?).to be false
        expect(result.errors).to be_present
      end

      it 'handles database errors gracefully' do
        allow(task).to receive(:update).and_raise(ActiveRecord::RecordInvalid.new(task))

        result = TaskCompletion.call(task: task, user: user)

        expect(result.success?).to be false
        expect(result.errors).to be_present
      end
    end

    context 'service is testable in isolation' do
      it 'validates inputs before performing operation' do
        result = TaskCompletion.call(task: nil, user: user)

        expect(result.success?).to be false
      end
    end
  end
end

