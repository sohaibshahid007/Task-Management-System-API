class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAILER_FROM", "noreply@taskmanager.com")
  
  # For API-only apps, we can use plain text emails without templates
  # Or create minimal templates if needed
  def self.inherited(subclass)
    super
    subclass.default template_path: "mailers/#{subclass.name.underscore}"
  end
end
