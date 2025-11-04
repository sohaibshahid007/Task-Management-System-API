require 'rails_helper'

RSpec.describe TaskArchivalJob, type: :job do
  describe 'Sidekiq configuration' do
    it 'uses low_priority queue' do
      options = described_class.sidekiq_options
      expect(options['queue']).to eq(:low_priority)
    end

    it 'has retry count of 3' do
      options = described_class.sidekiq_options
      expect(options['retry']).to eq(3)
    end
  end

  describe '#perform' do
    let!(:old_completed_task) do
      task = create(:task, status: :completed)
      task.update_column(:completed_at, 35.days.ago)
      task
    end
    let!(:recent_completed_task) do
      task = create(:task, status: :completed)
      task.update_column(:completed_at, 10.days.ago)
      task
    end
    let!(:pending_task) do
      create(:task, status: :pending, completed_at: nil)
    end

    it 'archives completed tasks older than 30 days' do
      expect {
        described_class.new.perform
      }.to change { old_completed_task.reload.status }.from('completed').to('archived')
    end

    it 'does not archive recent completed tasks' do
      expect {
        described_class.new.perform
      }.not_to change { recent_completed_task.reload.status }
    end

    it 'does not archive pending tasks' do
      expect {
        described_class.new.perform
      }.not_to change { pending_task.reload.status }
    end

    it 'logs number of archived tasks' do
      expect(Rails.logger).to receive(:info).with(/Archived \d+ tasks/)

      described_class.new.perform
    end

    context 'when multiple tasks need archiving' do
      let!(:old_task1) do
        task = create(:task, status: :completed)
        task.update_column(:completed_at, 31.days.ago)
        task
      end
      let!(:old_task2) do
        task = create(:task, status: :completed)
        task.update_column(:completed_at, 40.days.ago)
        task
      end
      let!(:old_task3) do
        task = create(:task, status: :completed)
        task.update_column(:completed_at, 50.days.ago)
        task
      end

      it 'archives all old completed tasks' do
        expect {
          described_class.new.perform
        }.to change { Task.where(status: :archived).count }.by(4) # 3 new + 1 existing
      end
    end

    context 'error handling' do
      it 'logs errors for individual task failures' do
        task = create(:task, status: :completed)
        task.update_column(:completed_at, 35.days.ago)
        task.errors.add(:base, 'Validation failed')
        allow(task).to receive(:update).and_return(false)
        allow(task).to receive(:errors).and_return(task.errors)
        allow(Task).to receive_message_chain(:where, :where, :find_each).and_yield(task)

        expect(Rails.logger).to receive(:error).at_least(:once)

        described_class.new.perform
      end

      it 'continues processing other tasks even if one fails' do
        failing_task = create(:task, status: :completed)
        failing_task.update_column(:completed_at, 35.days.ago)
        working_task = create(:task, status: :completed)
        working_task.update_column(:completed_at, 40.days.ago)

        failing_task.errors.add(:base, 'Error')
        allow(failing_task).to receive(:update).and_return(false)
        allow(failing_task).to receive(:errors).and_return(failing_task.errors)
        allow(Task).to receive_message_chain(:where, :where, :find_each).and_yield(failing_task).and_yield(working_task)

        # Should still archive the working task
        expect {
          described_class.new.perform
        }.to change { working_task.reload.status }.from('completed').to('archived')
      end

      it 'raises error on critical failures to trigger retry' do
        allow(Task).to receive(:where).and_raise(ActiveRecord::StatementInvalid.new('Database error'))

        expect {
          described_class.new.perform
        }.to raise_error(ActiveRecord::StatementInvalid)
      end

      it 'logs critical errors with backtrace' do
        error = StandardError.new('Critical error')
        allow(Task).to receive(:where).and_raise(error)

        expect(Rails.logger).to receive(:error).at_least(:once)

        begin
          described_class.new.perform
        rescue StandardError
          # Expected
        end
      end
    end

    context 'idempotency' do
      it 'can be safely run multiple times' do
        old_task = create(:task, status: :completed)
        old_task.update_column(:completed_at, 35.days.ago)

        # First run
        described_class.new.perform
        expect(old_task.reload.status).to eq('archived')

        # Second run - should not change already archived tasks
        expect {
          described_class.new.perform
        }.not_to change { old_task.reload.status }
      end

      it 'only processes tasks that need archiving' do
        old_task = create(:task, status: :completed)
        old_task.update_column(:completed_at, 35.days.ago)

        # First run
        described_class.new.perform
        expect(old_task.reload.status).to eq('archived')

        # Second run should not attempt to update already archived tasks
        # (The query excludes archived tasks, so it won't find them)
        expect {
          described_class.new.perform
        }.not_to raise_error
      end
    end

    context 'logging' do
      it 'logs successful archival count' do
        task = create(:task, status: :completed)
        task.update_column(:completed_at, 35.days.ago)

        expect(Rails.logger).to receive(:info).with(/Archived \d+ tasks/)

        described_class.new.perform
      end

      it 'logs warnings when errors occur' do
        task = create(:task, status: :completed)
        task.update_column(:completed_at, 35.days.ago)
        task.errors.add(:base, 'Error')
        allow(task).to receive(:update).and_return(false)
        allow(task).to receive(:errors).and_return(task.errors)
        allow(Task).to receive_message_chain(:where, :where, :find_each).and_yield(task)

        expect(Rails.logger).to receive(:warn).with(/Encountered \d+ errors/)

        described_class.new.perform
      end
    end
  end
end
