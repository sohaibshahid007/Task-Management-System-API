require 'rails_helper'

RSpec.describe TaskNotificationJob, type: :job do
  describe 'Sidekiq configuration' do
    it 'uses default queue' do
      options = described_class.sidekiq_options
      expect(options['queue']).to eq(:default)
    end

    it 'has retry count of 3' do
      options = described_class.sidekiq_options
      expect(options['retry']).to eq(3)
    end
  end

  describe '#perform' do
    let(:task) { create(:task, assignee: create(:user)) }
    let(:creator) { task.creator }

    context 'when task is created' do
      it 'sends assignment notification to assignee' do
        mailer_double = double('mailer')
        expect(TaskMailer).to receive(:task_assigned).with(task).and_return(mailer_double)
        expect(mailer_double).to receive(:deliver_now)

        described_class.new.perform(task.id, 'created')
      end

      it 'does not send notification if task has no assignee' do
        task_without_assignee = create(:task, assignee: nil)
        expect(TaskMailer).not_to receive(:task_assigned)

        described_class.new.perform(task_without_assignee.id, 'created')
      end
    end

    context 'when task is assigned' do
      it 'sends assignment notification to assignee' do
        mailer_double = double('mailer')
        expect(TaskMailer).to receive(:task_assigned).with(task).and_return(mailer_double)
        expect(mailer_double).to receive(:deliver_now)

        described_class.new.perform(task.id, 'assigned')
      end
    end

    context 'when task is completed' do
      let(:completed_task) { create(:task, status: :completed, creator: creator) }

      it 'sends completion notification to creator' do
        mailer_double = double('mailer')
        expect(TaskMailer).to receive(:task_completed).with(completed_task).and_return(mailer_double)
        expect(mailer_double).to receive(:deliver_now)

        described_class.new.perform(completed_task.id, 'completed')
      end

      it 'handles missing creator gracefully' do
        completed_task_without_creator = create(:task, status: :completed)
        allow(completed_task_without_creator).to receive(:creator).and_return(nil)
        allow(Task).to receive(:find_by).with(id: completed_task_without_creator.id).and_return(completed_task_without_creator)

        expect(TaskMailer).not_to receive(:task_completed)

        described_class.new.perform(completed_task_without_creator.id, 'completed')
      end
    end

    context 'with invalid action' do
      it 'logs warning and does not send notification' do
        expect(Rails.logger).to receive(:warn).with(/Unknown action/)
        expect(TaskMailer).not_to receive(:task_assigned)
        expect(TaskMailer).not_to receive(:task_completed)

        described_class.new.perform(task.id, 'invalid_action')
      end
    end

    context 'error handling' do
      context 'when task_id is missing' do
        it 'logs error and returns early' do
          expect(Rails.logger).to receive(:error).with(/Task ID is required/)
          expect(TaskMailer).not_to receive(:task_assigned)

          described_class.new.perform(nil, 'created')
        end
      end

      context 'when action is missing' do
        it 'logs error and returns early' do
          expect(Rails.logger).to receive(:error).with(/Action is required/)
          expect(TaskMailer).not_to receive(:task_assigned)

          described_class.new.perform(task.id, nil)
        end
      end

      context 'when task not found' do
        it 'logs error and returns early (idempotent)' do
          expect(Rails.logger).to receive(:error).with(/Task not found/)
          expect(TaskMailer).not_to receive(:task_assigned)

          # Should not raise error, just log and return (idempotent behavior)
          expect { described_class.new.perform(999999, 'created') }.not_to raise_error
        end
      end

      context 'when mailer fails' do
        it 'raises error to trigger retry' do
          allow(TaskMailer).to receive(:task_assigned).and_raise(StandardError, 'Mail delivery failed')

          expect {
            described_class.new.perform(task.id, 'created')
          }.to raise_error(StandardError, 'Mail delivery failed')
        end

        it 'logs error details' do
          error = StandardError.new('Mail delivery failed')
          allow(TaskMailer).to receive(:task_assigned).and_raise(error)

          expect(Rails.logger).to receive(:error).at_least(:once)

          begin
            described_class.new.perform(task.id, 'created')
          rescue StandardError
          end
        end
      end
    end

    context 'idempotency' do
      it 'can be safely called multiple times with same parameters' do
        mailer_double = double('mailer')
        allow(TaskMailer).to receive(:task_assigned).and_return(mailer_double)
        allow(mailer_double).to receive(:deliver_now)
        described_class.new.perform(task.id, 'created')
        described_class.new.perform(task.id, 'created')
        expect(TaskMailer).to have_received(:task_assigned).with(task).twice
      end
    end

    context 'logging' do
      it 'executes without critical errors' do
        mailer_double = double('mailer')
        allow(TaskMailer).to receive(:task_assigned).and_return(mailer_double)
        allow(mailer_double).to receive(:deliver_now)

        expect {
          described_class.new.perform(task.id, 'created')
        }.not_to raise_error
      end
    end
  end
end
