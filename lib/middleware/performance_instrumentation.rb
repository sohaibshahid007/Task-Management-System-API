# Custom Performance Instrumentation Middleware
# Tracks request performance metrics: response time, query count, memory usage
module Middleware
  class PerformanceInstrumentation
    def initialize(app)
      @app = app
    end

    def call(env)
      start_time = Time.current
      start_memory = memory_usage
      query_count_start = query_count
      
      # Track Active Record queries
      query_log = []
      subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |name, start, finish, id, payload|
        query_log << {
          sql: payload[:sql],
          name: payload[:name],
          duration: ((finish - start) * 1000).round(2) # Convert to milliseconds
        }
      end
      
      status, headers, response = @app.call(env)
      
      # Calculate metrics
      duration = ((Time.current - start_time) * 1000).round(2) # milliseconds
      memory_delta = memory_usage - start_memory
      query_count_end = query_count
      total_queries = query_count_end - query_count_start
      
      # Unsubscribe from notifications
      ActiveSupport::Notifications.unsubscribe(subscriber)
      
      # Log performance metrics
      log_performance_metrics(
        env: env,
        duration: duration,
        memory_delta: memory_delta,
        query_count: total_queries,
        slow_queries: query_log.select { |q| q[:duration] > 100 } # Queries > 100ms
      )
      
      # Add performance headers (useful for monitoring tools)
      headers['X-Response-Time'] = "#{duration}ms"
      headers['X-Query-Count'] = total_queries.to_s
      headers['X-Memory-Delta'] = "#{memory_delta}KB"
      
      [status, headers, response]
    rescue StandardError => e
      Rails.logger.error "PerformanceInstrumentation error: #{e.class} - #{e.message}"
      @app.call(env)
    end

    private

    def log_performance_metrics(env:, duration:, memory_delta:, query_count:, slow_queries:)
      request = ActionDispatch::Request.new(env)
      path = request.path
      method = request.method
      
      # Log to Rails logger
      Rails.logger.info "[Performance] #{method} #{path} | " \
                        "Duration: #{duration}ms | " \
                        "Queries: #{query_count} | " \
                        "Memory: #{memory_delta}KB"
      
      # Warn about slow requests
      if duration > 1000 # > 1 second
        Rails.logger.warn "[Performance] SLOW REQUEST: #{method} #{path} took #{duration}ms"
      end
      
      # Warn about high query count
      if query_count > 20
        Rails.logger.warn "[Performance] HIGH QUERY COUNT: #{method} #{path} executed #{query_count} queries"
      end
      
      # Log slow queries
      if slow_queries.any?
        Rails.logger.warn "[Performance] SLOW QUERIES detected in #{method} #{path}:"
        slow_queries.each do |query|
          Rails.logger.warn "  - #{query[:name]}: #{query[:duration]}ms | #{query[:sql].truncate(100)}"
        end
      end
      
      # Log high memory usage
      if memory_delta > 50_000 # > 50MB
        Rails.logger.warn "[Performance] HIGH MEMORY USAGE: #{method} #{path} used #{memory_delta}KB"
      end
    end

    def memory_usage
      # Get memory usage in KB (works on Unix-like systems)
      if File.exist?('/proc/self/status')
        `grep VmRSS /proc/self/status`.split[1].to_i
      else
        # Fallback for macOS
        `ps -o rss= -p #{Process.pid}`.to_i
      end
    rescue StandardError
      0
    end

    def query_count
      # Get current query count from Active Record
      ActiveRecord::Base.connection.query_cache.size
    rescue StandardError
      0
    end
  end
end

