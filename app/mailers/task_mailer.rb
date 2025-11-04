class TaskMailer < ApplicationMailer
  def task_assigned(task)
    @task = task
    @assignee = task.assignee
    mail(to: @assignee.email, subject: I18n.t("mailers.task.assigned_subject", title: task.title))
  end

  def task_completed(task)
    @task = task
    @creator = task.creator
    mail(to: @creator.email, subject: I18n.t("mailers.task.completed_subject", title: task.title))
  end

  def task_reminder(task)
    @task = task
    @assignee = task.assignee
    mail(to: @assignee.email, subject: I18n.t("mailers.task.reminder_subject", title: task.title))
  end

  def data_export(user, csv_data)
    @user = user
    attachments["tasks_export_#{Date.current}.csv"] = csv_data
    mail(to: @user.email, subject: I18n.t("mailers.task.export_subject"))
  end
end
