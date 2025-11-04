class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  enum :role, { member: 0, manager: 1, admin: 2 }

  validates :email, presence: true, uniqueness: { case_sensitive: false }
  validates :first_name, presence: true
  validates :last_name, presence: true

  has_many :created_tasks, class_name: "Task", foreign_key: "creator_id", dependent: :destroy
  has_many :assigned_tasks, class_name: "Task", foreign_key: "assignee_id", dependent: :nullify
  has_many :comments, dependent: :destroy

  def full_name
    "#{first_name} #{last_name}".strip
  end

  def admin?
    role == "admin"
  end

  def manager?
    role == "manager"
  end

  def member?
    role == "member"
  end
end
