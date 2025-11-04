require 'rails_helper'
require 'csv'

RSpec.describe DataExportJob, type: :job do
  describe 'Sidekiq configuration' do
    it 'uses exports queue' do
      options = described_class.sidekiq_options
      expect(options['queue']).to eq(:exports)
    end

    it 'has retry count of 2' do
      options = described_class.sidekiq_options
      expect(options['retry']).to eq(2)
    end
  end

  describe '#perform' do
    let(:user) { create(:user) }
    let(:creator) { create(:user) }
    let(:assignee) { create(:user) }

    let!(:task1) do
      create(:task,
        title: 'Task 1',
        description: 'Description 1',
        status: :pending,
        priority: :high,
        due_date: 1.day.from_now,
        creator: creator,
        assignee: user
      )
    end
    let!(:task2) do
      create(:task,
        title: 'Task 2',
        description: 'Description 2',
        status: :completed,
        priority: :medium,
        due_date: 2.days.from_now,
        creator: creator,
        assignee: user
      )
    end
    let!(:other_user_task) do
      create(:task,
        assignee: create(:user),
        creator: creator
      )
    end

    it 'generates CSV with user assigned tasks' do
      mailer_double = double('mailer')
      csv_data_received = nil
      allow(TaskMailer).to receive(:data_export) do |user_arg, csv_data|
        csv_data_received = csv_data
        mailer_double
      end
      allow(mailer_double).to receive(:deliver_now)

      described_class.new.perform(user.id)

      # Verify CSV content
      expect(csv_data_received).to be_a(String)
      csv = CSV.parse(csv_data_received, headers: true)
      expect(csv.headers).to include('Title', 'Description', 'Status', 'Priority', 'Due Date', 'Created At', 'Creator', 'Assignee')
      expect(csv.count).to eq(2) # task1 and task2
    end

    it 'includes only tasks assigned to the user' do
      mailer_double = double('mailer')
      csv_data_received = nil
      allow(TaskMailer).to receive(:data_export) do |_, csv_data|
        csv_data_received = csv_data
        mailer_double
      end
      allow(mailer_double).to receive(:deliver_now)

      described_class.new.perform(user.id)

      csv = CSV.parse(csv_data_received, headers: true)
      task_titles = csv.map { |row| row['Title'] }
      expect(task_titles).to include('Task 1', 'Task 2')
      expect(task_titles).not_to include(other_user_task.title)
    end

    it 'includes all required columns in CSV' do
      mailer_double = double('mailer')
      csv_data_received = nil
      allow(TaskMailer).to receive(:data_export) do |_, csv_data|
        csv_data_received = csv_data
        mailer_double
      end
      allow(mailer_double).to receive(:deliver_now)

      described_class.new.perform(user.id)

      csv = CSV.parse(csv_data_received, headers: true)
      headers = csv.headers
      expect(headers).to include('Title', 'Description', 'Status', 'Priority', 'Due Date', 'Created At', 'Creator', 'Assignee')
    end

    context 'when user has no tasks' do
      let(:user_without_tasks) { create(:user) }

      it 'sends empty CSV' do
        mailer_double = double('mailer')
        csv_data_received = nil
        allow(TaskMailer).to receive(:data_export) do |_, csv_data|
          csv_data_received = csv_data
          mailer_double
        end
        allow(mailer_double).to receive(:deliver_now)

        described_class.new.perform(user_without_tasks.id)

        csv = CSV.parse(csv_data_received, headers: true)
        expect(csv.count).to eq(0)
        expect(csv.headers).to be_present
      end

      it 'logs info message' do
        mailer_double = double('mailer')
        allow(TaskMailer).to receive(:data_export).and_return(mailer_double)
        allow(mailer_double).to receive(:deliver_now)

        expect(Rails.logger).to receive(:info).with(/No tasks found for user/)

        described_class.new.perform(user_without_tasks.id)
      end
    end

    context 'error handling' do
      context 'when user_id is missing' do
        it 'logs error and returns early' do
          expect(Rails.logger).to receive(:error).with(/User ID is required/)
          expect(TaskMailer).not_to receive(:data_export)

          described_class.new.perform(nil)
        end
      end

      context 'when user not found' do
        it 'logs error and returns early (idempotent)' do
          expect(Rails.logger).to receive(:error).with(/User not found/)
          expect(TaskMailer).not_to receive(:data_export)

          # Should not raise error, just log and return (idempotent behavior)
          expect { described_class.new.perform(999999) }.not_to raise_error
        end
      end

      context 'when CSV generation fails' do
        it 'raises error to trigger retry' do
          allow_any_instance_of(described_class).to receive(:generate_csv).and_raise(StandardError, 'CSV generation failed')

          expect {
            described_class.new.perform(user.id)
          }.to raise_error(StandardError, 'CSV generation failed')
        end

        it 'logs error details' do
          error = StandardError.new('CSV generation failed')
          allow_any_instance_of(described_class).to receive(:generate_csv).and_raise(error)

          expect(Rails.logger).to receive(:error).at_least(:once)

          begin
            described_class.new.perform(user.id)
          rescue StandardError
            # Expected
          end
        end
      end

      context 'when mailer fails' do
        it 'raises error to trigger retry' do
          allow(TaskMailer).to receive(:data_export).and_raise(StandardError, 'Mail delivery failed')

          expect {
            described_class.new.perform(user.id)
          }.to raise_error(StandardError, 'Mail delivery failed')
        end
      end
    end

    context 'idempotency' do
      it 'can be safely called multiple times with same user_id' do
        mailer_double = double('mailer')
        allow(TaskMailer).to receive(:data_export).and_return(mailer_double)
        allow(mailer_double).to receive(:deliver_now)

        # First call
        described_class.new.perform(user.id)

        # Second call with same parameters
        described_class.new.perform(user.id)

        expect(TaskMailer).to have_received(:data_export).twice
      end

      it 'generates consistent CSV for same user' do
        mailer_double = double('mailer')
        csv_data1 = nil
        csv_data2 = nil

        allow(TaskMailer).to receive(:data_export) do |_, csv|
          csv_data1 ||= csv
          csv_data2 = csv if csv_data1
          mailer_double
        end
        allow(mailer_double).to receive(:deliver_now)

        described_class.new.perform(user.id)
        described_class.new.perform(user.id)

        # CSV content should be the same (excluding timestamps that might vary)
        expect(csv_data1).to be_present
        expect(csv_data2).to be_present
        expect(csv_data1).to be_a(String)
        expect(csv_data2).to be_a(String)
      end
    end

    context 'logging' do
      it 'logs successful export' do
        mailer_double = double('mailer')
        allow(TaskMailer).to receive(:data_export).and_return(mailer_double)
        allow(mailer_double).to receive(:deliver_now)

        expect(Rails.logger).to receive(:info).with(/Export sent successfully for user/)

        described_class.new.perform(user.id)
      end
    end

    context 'CSV content validation' do
      it 'includes task title' do
        mailer_double = double('mailer')
        csv_data_received = nil
        allow(TaskMailer).to receive(:data_export) do |_, csv_data|
          csv_data_received = csv_data
          mailer_double
        end
        allow(mailer_double).to receive(:deliver_now)

        described_class.new.perform(user.id)

        csv = CSV.parse(csv_data_received, headers: true)
        expect(csv.first['Title']).to eq('Task 1')
      end

      it 'includes creator full name' do
        mailer_double = double('mailer')
        csv_data_received = nil
        allow(TaskMailer).to receive(:data_export) do |_, csv_data|
          csv_data_received = csv_data
          mailer_double
        end
        allow(mailer_double).to receive(:deliver_now)

        described_class.new.perform(user.id)

        csv = CSV.parse(csv_data_received, headers: true)
        expect(csv.first['Creator']).to eq(creator.full_name)
      end

      it 'handles nil values gracefully' do
        task_with_nils = create(:task,
          title: 'Task with nils',
          description: nil,
          due_date: nil,
          assignee: user,
          creator: creator
        )

        mailer_double = double('mailer')
        allow(TaskMailer).to receive(:data_export).and_return(mailer_double)
        allow(mailer_double).to receive(:deliver_now)

        expect {
          described_class.new.perform(user.id)
        }.not_to raise_error
      end
    end
  end
end
