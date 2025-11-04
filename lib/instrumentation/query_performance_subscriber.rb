# Custom Active Record Query Performance Subscriber
# Tracks query performance metrics and logs slow queries
module Instrumentation
  class QueryPerformanceSubscriber
    def self.subscribe
      ActiveSupport::Notifications.subscribe("sql.active_record") do |name, start, finish, id, payload|
        duration = ((finish - start) * 1000).round(2) # Convert to milliseconds

        # Log slow queries (> 100ms)
        if duration > 100
          Rails.logger.warn "[Query Performance] SLOW QUERY detected:"
          Rails.logger.warn "  Duration: #{duration}ms"
          Rails.logger.warn "  Name: #{payload[:name]}"
          Rails.logger.warn "  SQL: #{payload[:sql].truncate(200)}"
          Rails.logger.warn "  Connection: #{payload[:connection_id]}" if payload[:connection_id]
        end

        # Log very slow queries (> 500ms) as errors
        if duration > 500
          Rails.logger.error "[Query Performance] VERY SLOW QUERY: #{duration}ms"
          Rails.logger.error "  Full SQL: #{payload[:sql]}"
          Rails.logger.error "  Backtrace: #{caller.first(5).join("\n")}"
        end
      end
    end
  end
end
