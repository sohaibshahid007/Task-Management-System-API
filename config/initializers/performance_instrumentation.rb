# Performance Instrumentation Configuration
# Custom middleware and subscribers for performance monitoring

if Rails.env.development? || Rails.env.test?
  # Load custom performance instrumentation middleware
  require Rails.root.join("lib", "middleware", "performance_instrumentation")
  
  # Add performance instrumentation middleware to the stack
  # Insert after Rack::Cors but early enough to catch all requests
  Rails.application.config.middleware.use Middleware::PerformanceInstrumentation
  
  # Subscribe to query performance events
  require Rails.root.join("lib", "instrumentation", "query_performance_subscriber")
  Instrumentation::QueryPerformanceSubscriber.subscribe
  
  Rails.logger.info "Performance instrumentation enabled" if Rails.env.development?
end

