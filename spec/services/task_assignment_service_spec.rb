require 'rails_helper'

RSpec.describe TaskAssignment do
  let(:task) { create(:task) }
  let(:assignee) { create(:user) }

  describe '.call' do
    context 'with authorized user (admin)' do
      let(:admin) { create(:user, :admin) }

      it 'assigns task successfully' do
        result = TaskAssignment.call(task: task, assignee: assignee, assigned_by: admin)

        expect(result.success?).to be true
        expect(task.reload.assignee).to eq(assignee)
      end

      it 'returns consistent result object' do
        result = TaskAssignment.call(task: task, assignee: assignee, assigned_by: admin)

        expect(result).to respond_to(:success?)
        expect(result).to respond_to(:data)
        expect(result).to respond_to(:errors)
        expect(result.success?).to be true
        expect(result.data).to be_a(Task)
      end

      it 'updates task assignee' do
        task_without_assignee = create(:task, assignee: nil)
        expect {
          TaskAssignment.call(task: task_without_assignee, assignee: assignee, assigned_by: admin)
        }.to change { task_without_assignee.reload.assignee }.from(nil).to(assignee)
      end

      it 'sends assignment notification via Sidekiq' do
        expect {
          TaskAssignment.call(task: task, assignee: assignee, assigned_by: admin)
        }.to change { TaskNotificationJob.jobs.size }.by(1)

        job = TaskNotificationJob.jobs.last
        expect(job['args']).to eq([ task.id, 'assigned' ])
      end

      it 'returns updated task in result data' do
        result = TaskAssignment.call(task: task, assignee: assignee, assigned_by: admin)

        expect(result.data.assignee).to eq(assignee)
      end
    end

    context 'with authorized user (manager)' do
      let(:manager) { create(:user, :manager) }

      it 'assigns task successfully' do
        result = TaskAssignment.call(task: task, assignee: assignee, assigned_by: manager)

        expect(result.success?).to be true
        expect(task.reload.assignee).to eq(assignee)
      end

      it 'sends notification when manager assigns task' do
        expect {
          TaskAssignment.call(task: task, assignee: assignee, assigned_by: manager)
        }.to change { TaskNotificationJob.jobs.size }.by(1)
      end
    end

    context 'with unauthorized user (member)' do
      let(:member) { create(:user, :member) }

      it 'returns failure with authorization error' do
        result = TaskAssignment.call(task: task, assignee: assignee, assigned_by: member)

        expect(result.success?).to be false
        expect(result.errors).to include('You are not authorized to assign tasks')
        expect(result.data).to be_nil
      end

      it 'does not update task assignee' do
        original_assignee = task.assignee
        TaskAssignment.call(task: task, assignee: assignee, assigned_by: member)

        expect(task.reload.assignee).to eq(original_assignee)
      end

      it 'does not send notification when unauthorized' do
        expect {
          TaskAssignment.call(task: task, assignee: assignee, assigned_by: member)
        }.not_to change { TaskNotificationJob.jobs.size }
      end
    end

    context 'with invalid assignee' do
      let(:admin) { create(:user, :admin) }

      it 'validates assignee exists' do
        result = TaskAssignment.call(task: task, assignee: nil, assigned_by: admin)

        expect(result.success?).to be false
        expect(result.errors).to include('Assignee not found')
      end

      it 'does not update task when assignee is invalid' do
        original_assignee = task.assignee
        TaskAssignment.call(task: task, assignee: nil, assigned_by: admin)

        expect(task.reload.assignee).to eq(original_assignee)
      end

      it 'does not send notification when assignee is invalid' do
        expect {
          TaskAssignment.call(task: task, assignee: nil, assigned_by: admin)
        }.not_to change { TaskNotificationJob.jobs.size }
      end
    end

    context 'when task is already assigned to same user' do
      let(:admin) { create(:user, :admin) }
      let(:assigned_task) { create(:task, assignee: assignee) }

      it 'returns failure with appropriate message' do
        result = TaskAssignment.call(task: assigned_task, assignee: assignee, assigned_by: admin)

        expect(result.success?).to be false
        expect(result.errors).to include('Task is already assigned to this user')
      end

      it 'does not send duplicate notification' do
        expect {
          TaskAssignment.call(task: assigned_task, assignee: assignee, assigned_by: admin)
        }.not_to change { TaskNotificationJob.jobs.size }
      end
    end

    context 'error handling' do
      let(:admin) { create(:user, :admin) }

      it 'validates task parameter' do
        result = TaskAssignment.call(task: nil, assignee: assignee, assigned_by: admin)

        expect(result.success?).to be false
        expect(result.errors).to be_present
      end

      it 'validates assigned_by parameter' do
        result = TaskAssignment.call(task: task, assignee: assignee, assigned_by: nil)

        expect(result.success?).to be false
        expect(result.errors).to be_present
      end

      it 'handles database errors gracefully' do
        allow(task).to receive(:update).and_raise(ActiveRecord::RecordInvalid.new(task))

        result = TaskAssignment.call(task: task, assignee: assignee, assigned_by: admin)

        expect(result.success?).to be false
        expect(result.errors).to be_present
      end

      it 'handles task update failures' do
        task.errors.add(:base, 'Validation error')
        allow(task).to receive(:update).and_return(false)
        allow(task).to receive(:errors).and_return(task.errors)

        result = TaskAssignment.call(task: task, assignee: assignee, assigned_by: admin)

        expect(result.success?).to be false
        expect(result.errors).to be_present
        expect(result.errors).to be_an(Array)
      end
    end

    context 'service is testable in isolation' do
      let(:admin) { create(:user, :admin) }

      it 'checks authorization before performing operation' do
        member = create(:user, :member)
        result = TaskAssignment.call(task: task, assignee: assignee, assigned_by: member)

        expect(result.success?).to be false
      end

      it 'validates inputs before performing operation' do
        result = TaskAssignment.call(task: nil, assignee: assignee, assigned_by: admin)

        expect(result.success?).to be false
      end
    end

    context 'Single Responsibility Principle' do
      let(:admin) { create(:user, :admin) }

      it 'only handles task assignment logic' do
        result = TaskAssignment.call(task: task, assignee: assignee, assigned_by: admin)

        expect(result.success?).to be true
      end
    end
  end
end
