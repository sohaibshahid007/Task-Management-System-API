class Task < ApplicationRecord
  enum :status, { pending: 0, in_progress: 1, completed: 2, archived: 3 }
  enum :priority, { low: 0, medium: 1, high: 2, urgent: 3 }

  belongs_to :creator, class_name: "User"
  belongs_to :assignee, class_name: "User", optional: true
  has_many :comments, dependent: :destroy

  validates :title, presence: true
  validates :status, presence: true
  validates :priority, presence: true

  scope :by_status, ->(status) { where(status: status) }
  scope :by_priority, ->(priority) { where(priority: priority) }
  scope :overdue, -> { where("due_date < ? AND status != ?", Time.current, statuses[:completed]) }
  scope :upcoming, ->(days = 7) { where("due_date BETWEEN ? AND ?", Time.current, days.days.from_now) }
  scope :completed_between, ->(start_date, end_date) { where(status: :completed, completed_at: start_date..end_date) }
  scope :assigned_to, ->(user) { where(assignee_id: user.id) }
  scope :created_by, ->(user) { where(creator_id: user.id) }
  scope :recent, -> { order(created_at: :desc) }
  scope :high_priority, -> { where(priority: [ priorities[:high], priorities[:urgent] ]) }

  before_save :set_completed_at, if: :will_save_change_to_status?

  def overdue?
    due_date.present? && due_date < Time.current && !completed?
  end

  def assignee_name
    assignee&.full_name
  end

  def creator_name
    creator&.full_name
  end

  private

  def set_completed_at
    self.completed_at = completed? ? Time.current : nil
  end
end
