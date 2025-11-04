require 'rails_helper'

RSpec.describe Middleware::SidekiqErrorTrackingMiddleware do
  let(:worker) { double('worker', class: TaskNotificationJob) }
  let(:job) { { 'class' => 'TaskNotificationJob', 'jid' => 'abc123', 'retry_count' => 2 } }
  let(:queue) { 'default' }
  let(:middleware) { described_class.new }

  describe '#call' do
    context 'when job succeeds' do
      it 'does not track errors' do
        expect(Rails.logger).not_to receive(:error).with(/Sidekiq Error Tracking/)

        middleware.call(worker, job, queue) do
        end
      end
    end

    context 'when job fails' do
      it 'tracks error details' do
        error = StandardError.new('Job execution failed')

        expect(Rails.logger).to receive(:error).with(/Sidekiq Error Tracking/) do |message|
          expect(message).to include('TaskNotificationJob')
          expect(message).to include('abc123')
          expect(message).to include('default')
          expect(message).to include('StandardError')
          expect(message).to include('Job execution failed')
          expect(message).to include('"retry_count":2')
        end

        expect {
          middleware.call(worker, job, queue) do
            raise error
          end
        }.to raise_error(StandardError, 'Job execution failed')
      end

      it 'includes job class in error details' do
        error = StandardError.new('Error')
        allow(Rails.logger).to receive(:error)

        expect {
          middleware.call(worker, job, queue) do
            raise error
          end
        }.to raise_error

        expect(Rails.logger).to have_received(:error).with(/TaskNotificationJob/)
      end

      it 'includes queue name in error details' do
        error = StandardError.new('Error')
        allow(Rails.logger).to receive(:error)

        expect {
          middleware.call(worker, job, queue) do
            raise error
          end
        }.to raise_error

        expect(Rails.logger).to have_received(:error).with(/default/)
      end

      it 'includes retry count in error details' do
        error = StandardError.new('Error')
        allow(Rails.logger).to receive(:error)

        expect {
          middleware.call(worker, job, queue) do
            raise error
          end
        }.to raise_error

        expect(Rails.logger).to have_received(:error).with(/retry_count/)
      end

      it 're-raises error to trigger Sidekiq retry' do
        error = StandardError.new('Job failed')

        expect {
          middleware.call(worker, job, queue) do
            raise error
          end
        }.to raise_error(StandardError, 'Job failed')
      end

      context 'when retry_count is not present' do
        let(:job) { { 'class' => 'TaskNotificationJob', 'jid' => 'abc123' } }

        it 'defaults retry_count to 0' do
          error = StandardError.new('Error')
          allow(Rails.logger).to receive(:error)

          expect {
            middleware.call(worker, job, queue) do
              raise error
            end
          }.to raise_error

          expect(Rails.logger).to have_received(:error).with(/"retry_count":0/)
        end
      end
    end
  end
end
