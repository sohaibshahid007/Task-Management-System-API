class CommentPolicy < ApplicationPolicy
  def create?
    true
  end

  def destroy?
    owner? || task_owner? || admin?
  end

  private

  def owner?
    record.user_id == user.id
  end

  def task_owner?
    record.task.creator_id == user.id
  end

  def admin?
    user.admin?
  end
end
