# Bullet gem configuration for N+1 query detection
# https://github.com/flyerhzm/bullet
# Note: Bullet is only available in test environment

if defined?(Bullet)
  # Test environment only
  if Rails.env.test?
    Bullet.enable = true
    
    # Raise error in tests to catch N+1 queries
    Bullet.raise = true
    
    # Log warnings
    Bullet.console = true
    Bullet.rails_logger = true
    
    # Don't show browser notifications in tests
    Bullet.alert = false
    Bullet.bullet_logger = false
    Bullet.add_footer = false
    
    # Performance monitoring integrations (disabled)
    Bullet.honeybadger = false
    Bullet.bugsnag = false
    Bullet.airbrake = false
    Bullet.rollbar = false
    Bullet.sentry = false
  else
    # Disabled in development and production
    Bullet.enable = false
  end
end

