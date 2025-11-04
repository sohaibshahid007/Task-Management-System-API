require 'rails_helper'

RSpec.describe Middleware::PerformanceInstrumentation, type: :middleware do
  let(:app) { ->(env) { [200, {}, ['OK']] } }
  let(:middleware) { described_class.new(app) }
  let(:env) { Rack::MockRequest.env_for('/api/v1/tasks') }

  before do
    # Mock memory usage
    allow_any_instance_of(described_class).to receive(:memory_usage).and_return(1000)
    allow_any_instance_of(described_class).to receive(:query_count).and_return(0)
  end

  describe '#call' do
    it 'processes requests and adds performance headers' do
      status, headers, _body = middleware.call(env)

      expect(status).to eq(200)
      expect(headers['X-Response-Time']).to be_present
      expect(headers['X-Query-Count']).to be_present
      expect(headers['X-Memory-Delta']).to be_present
    end

    it 'logs performance metrics' do
      expect(Rails.logger).to receive(:info).with(/\[Performance\]/)
      middleware.call(env)
    end

    it 'warns about slow requests' do
      allow_any_instance_of(described_class).to receive(:call).and_wrap_original do |method, *args|
        allow(method.receiver).to receive(:log_performance_metrics) do |**kwargs|
          expect(kwargs[:duration]).to be > 0
        end
        method.call(*args)
      end
      
      # Simulate slow request
      allow(Time).to receive(:current).and_return(Time.current, Time.current + 2.seconds)
      
      expect(Rails.logger).to receive(:warn).with(/SLOW REQUEST/)
      middleware.call(env)
    end
  end
end

