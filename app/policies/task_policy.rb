class TaskPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      case user.role
      when "admin"
        scope.all
      when "manager"
        scope.all
      when "member"
        scope.where("creator_id = ? OR assignee_id = ?", user.id, user.id)
      else
        scope.none
      end
    end
  end

  def index?
    true
  end

  def show?
    return false unless record
    admin? || manager? || (member? && (record.creator_id == user.id || record.assignee_id == user.id))
  end

  def create?
    true
  end

  def update?
    return false if record.nil?
    admin? || manager? || (member? && record.creator_id == user.id)
  end

  def edit?
    update?
  end

  def destroy?
    admin?
  end

  def assign?
    return false if record.nil?
    admin? || manager?
  end

  def complete?
    return false if record.nil?
    show?
  end

  def dashboard?
    index?
  end

  private

  def admin?
    user.admin?
  end

  def manager?
    user.manager?
  end

  def member?
    user.member?
  end
end
