require "csv"

class DataExportJob
  include Sidekiq::Job
  sidekiq_options queue: :exports, retry: 2

  def perform(user_id)
    unless user_id.present?
      Rails.logger.error "DataExportJob failed: User ID is required"
      return
    end

    user = User.find_by(id: user_id)
    unless user
      Rails.logger.error "DataExportJob failed: User not found with id #{user_id}"
      return
    end

    begin
      tasks = user.assigned_tasks.includes(:creator, :assignee)

      if tasks.empty?
        Rails.logger.info "DataExportJob: No tasks found for user #{user_id}"
        TaskMailer.data_export(user, generate_empty_csv).deliver_now
        return
      end

      csv_data = generate_csv(tasks)
      TaskMailer.data_export(user, csv_data).deliver_now
      Rails.logger.info "DataExportJob: Export sent successfully for user #{user_id}"
    rescue StandardError => e
      Rails.logger.error "DataExportJob failed for user #{user_id}: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      raise # Re-raise to trigger Sidekiq retry
    end
  end

  private

  def generate_csv(tasks)
    CSV.generate(headers: true) do |csv|
      csv << [ "Title", "Description", "Status", "Priority", "Due Date", "Created At", "Creator", "Assignee" ]

      tasks.each do |task|
        csv << [
          task.title,
          task.description,
          task.status,
          task.priority,
          task.due_date,
          task.created_at,
          task.creator&.full_name,
          task.assignee&.full_name
        ]
      end
    end
  end

  def generate_empty_csv
    CSV.generate(headers: true) do |csv|
      csv << [ "Title", "Description", "Status", "Priority", "Due Date", "Created At", "Creator", "Assignee" ]
    end
  end
end
