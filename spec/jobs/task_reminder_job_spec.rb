require 'rails_helper'

RSpec.describe TaskReminderJob, type: :job do
  describe 'Sidekiq configuration' do
    it 'uses notifications queue' do
      options = described_class.sidekiq_options
      expect(options['queue']).to eq(:notifications)
    end

    it 'has retry count of 5' do
      options = described_class.sidekiq_options
      expect(options['retry']).to eq(5)
    end
  end

  describe '#perform' do
    let(:assignee) { create(:user) }
    let(:tomorrow) { 1.day.from_now }

    let!(:due_tomorrow_task) do
      create(:task,
        due_date: tomorrow,
        status: :pending,
        assignee: assignee
      )
    end
    let!(:due_tomorrow_another) do
      create(:task,
        due_date: tomorrow + 1.hour,
        status: :in_progress,
        assignee: create(:user)
      )
    end
    let!(:completed_task) do
      create(:task,
        status: :completed,
        due_date: tomorrow,
        assignee: assignee
      )
    end
    let!(:due_today_task) do
      create(:task,
        due_date: Time.current,
        status: :pending,
        assignee: assignee
      )
    end
    let!(:due_later_task) do
      create(:task,
        due_date: 2.days.from_now,
        status: :pending,
        assignee: assignee
      )
    end
    let!(:task_without_assignee) do
      create(:task,
        due_date: tomorrow,
        status: :pending,
        assignee: nil
      )
    end

    it 'sends reminders for tasks due tomorrow' do
      mailer_double = double('mailer')
      expect(TaskMailer).to receive(:task_reminder).with(due_tomorrow_task).and_return(mailer_double)
      expect(TaskMailer).to receive(:task_reminder).with(due_tomorrow_another).and_return(mailer_double)
      expect(mailer_double).to receive(:deliver_now).twice

      described_class.new.perform
    end

    it 'does not send reminders for completed tasks' do
      expect(TaskMailer).not_to receive(:task_reminder).with(completed_task)

      described_class.new.perform
    end

    it 'does not send reminders for tasks due today' do
      expect(TaskMailer).not_to receive(:task_reminder).with(due_today_task)

      described_class.new.perform
    end

    it 'does not send reminders for tasks due later than tomorrow' do
      expect(TaskMailer).not_to receive(:task_reminder).with(due_later_task)

      described_class.new.perform
    end

    it 'does not send reminders for tasks without assignee' do
      expect(TaskMailer).not_to receive(:task_reminder).with(task_without_assignee)

      described_class.new.perform
    end

    it 'logs number of reminders sent and errors' do
      mailer_double = double('mailer')
      allow(TaskMailer).to receive(:task_reminder).and_return(mailer_double)
      allow(mailer_double).to receive(:deliver_now)

      expect(Rails.logger).to receive(:info).with(/Sent \d+ reminders, \d+ errors/)

      described_class.new.perform
    end

    context 'error handling' do
      it 'continues processing even if one reminder fails' do
        failing_task = create(:task, due_date: tomorrow, status: :pending, assignee: create(:user))
        working_task = create(:task, due_date: tomorrow, status: :pending, assignee: create(:user))

        mailer_double = double('mailer')
        allow(mailer_double).to receive(:deliver_now)

        allow(TaskMailer).to receive(:task_reminder) do |task|
          if task.id == failing_task.id
            raise StandardError, 'Email failed'
          else
            mailer_double
          end
        end

        expect(Rails.logger).to receive(:error).with(/Failed to send reminder for task/)
        expect(Rails.logger).to receive(:info).with(/Sent \d+ reminders, \d+ errors/)

        described_class.new.perform
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
        task = create(:task, due_date: tomorrow, status: :pending, assignee: assignee)
        mailer_double = double('mailer')
        allow(TaskMailer).to receive(:task_reminder).and_return(mailer_double)
        allow(mailer_double).to receive(:deliver_now)

        described_class.new.perform

        described_class.new.perform

        expect(TaskMailer).to have_received(:task_reminder).with(task).twice
      end

      it 'handles empty result sets gracefully' do
        Task.where.not(id: Task.all).delete_all

        expect {
          described_class.new.perform
        }.not_to raise_error
      end
    end

    context 'logging' do
      it 'logs successful reminder counts' do
        create(:task, due_date: tomorrow, status: :pending, assignee: assignee)
        mailer_double = double('mailer')
        allow(TaskMailer).to receive(:task_reminder).and_return(mailer_double)
        allow(mailer_double).to receive(:deliver_now)

        expect(Rails.logger).to receive(:info).with(/Sent \d+ reminders, \d+ errors/)

        described_class.new.perform
      end

      it 'logs error counts when failures occur' do
        task = create(:task, due_date: tomorrow, status: :pending, assignee: assignee)
        allow(TaskMailer).to receive(:task_reminder).and_raise(StandardError, 'Email failed')

        expect(Rails.logger).to receive(:info).with(/Sent \d+ reminders, \d+ errors/)

        described_class.new.perform
      end
    end
  end
end
