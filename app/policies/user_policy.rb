class UserPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      case user.role
      when "admin"
        scope.all
      when "manager"
        scope.all
      else
        scope.none
      end
    end
  end

  def index?
    admin? || manager?
  end

  def show?
    admin? || manager? || (record.id == user.id)
  end

  def create?
    admin?
  end

  def update?
    admin? || (record.id == user.id)
  end

  def destroy?
    admin?
  end

  private

  def admin?
    user.admin?
  end

  def manager?
    user.manager?
  end
end
