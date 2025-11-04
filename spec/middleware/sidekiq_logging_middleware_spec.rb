require 'rails_helper'

RSpec.describe Middleware::SidekiqLoggingMiddleware do
  let(:worker) { double('worker', class: TaskNotificationJob) }
  let(:job) { { 'class' => 'TaskNotificationJob', 'jid' => 'abc123' } }
  let(:queue) { 'default' }
  let(:middleware) { described_class.new }

  describe '#call' do
    context 'when job succeeds' do
      it 'logs job start and completion' do
        expect(Rails.logger).to receive(:info).with(/Starting job: TaskNotificationJob/)
        expect(Rails.logger).to receive(:info).with(/Completed job: TaskNotificationJob/)

        middleware.call(worker, job, queue) do
        end
      end

      it 'logs duration of job execution' do
        allow(Rails.logger).to receive(:info)

        middleware.call(worker, job, queue) do
          sleep 0.1
        end

        expect(Rails.logger).to have_received(:info).with(/in \d+\.\d+s/)
      end

      it 'includes job ID in logs' do
        expect(Rails.logger).to receive(:info).with(/JID: abc123/).at_least(:once)

        middleware.call(worker, job, queue) do
        end
      end
    end

    context 'when job fails' do
      it 'logs job start and failure' do
        error = StandardError.new('Job failed')

        expect(Rails.logger).to receive(:info).with(/Starting job: TaskNotificationJob/)
        expect(Rails.logger).to receive(:error).with(/Failed job: TaskNotificationJob/)
        expect(Rails.logger).to receive(:error).with(/Error: StandardError - Job failed/)

        expect {
          middleware.call(worker, job, queue) do
            raise error
          end
        }.to raise_error(StandardError, 'Job failed')
      end

      it 'logs duration even when job fails' do
        allow(Rails.logger).to receive(:info)
        allow(Rails.logger).to receive(:error)

        expect {
          middleware.call(worker, job, queue) do
            sleep 0.1
            raise StandardError, 'Job failed'
          end
        }.to raise_error(StandardError)

        expect(Rails.logger).to have_received(:error).with(/after \d+\.\d+s/)
      end

      it 're-raises error to trigger Sidekiq retry' do
        error = StandardError.new('Job failed')

        expect {
          middleware.call(worker, job, queue) do
            raise error
          end
        }.to raise_error(StandardError, 'Job failed')
      end
    end
  end
end
