require 'rails_helper'

RSpec.describe TaskPolicy, type: :policy do
  subject { described_class }

  let(:admin) { create(:user, :admin) }
  let(:manager) { create(:user, :manager) }
  let(:member) { create(:user, :member) }
  let(:other_member) { create(:user, :member) }
  let(:task) { create(:task, creator: member, assignee: member) }

  describe '#index?' do
    it 'allows all authenticated users' do
      expect(subject.new(admin, Task).index?).to be true
      expect(subject.new(manager, Task).index?).to be true
      expect(subject.new(member, Task).index?).to be true
    end
  end

  describe '#show?' do
    it 'allows admin to view any task' do
      expect(subject.new(admin, task).show?).to be true
    end

    it 'allows manager to view any task' do
      expect(subject.new(manager, task).show?).to be true
    end

    it 'allows member to view own tasks' do
      expect(subject.new(member, task).show?).to be true
    end

    it 'denies member to view other member tasks' do
      other_task = create(:task, creator: other_member)
      expect(subject.new(member, other_task).show?).to be false
    end
  end

  describe '#create?' do
    it 'allows all authenticated users' do
      expect(subject.new(admin, Task).create?).to be true
      expect(subject.new(manager, Task).create?).to be true
      expect(subject.new(member, Task).create?).to be true
    end
  end

  describe '#update?' do
    it 'allows admin to update any task' do
      expect(subject.new(admin, task).update?).to be true
    end

    it 'allows manager to update own tasks' do
      manager_task = create(:task, creator: manager)
      expect(subject.new(manager, manager_task).update?).to be true
    end

    it 'allows manager to update any task' do
      other_task = create(:task, creator: other_member)
      expect(subject.new(manager, other_task).update?).to be true
    end

    it 'allows member to update own tasks' do
      expect(subject.new(member, task).update?).to be true
    end

    it 'denies member to update other tasks' do
      other_task = create(:task, creator: other_member)
      expect(subject.new(member, other_task).update?).to be false
    end
  end

  describe '#destroy?' do
    it 'allows admin to delete any task' do
      expect(subject.new(admin, task).destroy?).to be true
    end

    it 'denies manager to delete tasks' do
      expect(subject.new(manager, task).destroy?).to be false
    end

    it 'denies member to delete tasks' do
      expect(subject.new(member, task).destroy?).to be false
    end
  end

  describe '#assign?' do
    it 'allows admin to assign tasks' do
      expect(subject.new(admin, task).assign?).to be true
    end

    it 'allows manager to assign tasks' do
      expect(subject.new(manager, task).assign?).to be true
    end

    it 'denies member to assign tasks' do
      expect(subject.new(member, task).assign?).to be false
    end
  end

  describe '#complete?' do
    it 'allows admin to complete any task' do
      expect(subject.new(admin, task).complete?).to be true
    end

    it 'allows manager to complete any task' do
      expect(subject.new(manager, task).complete?).to be true
    end

    it 'allows member to complete assigned task' do
      expect(subject.new(member, task).complete?).to be true
    end

    it 'denies member to complete unassigned task' do
      unassigned_task = create(:task, creator: other_member, assignee: nil)
      expect(subject.new(member, unassigned_task).complete?).to be false
    end

    it 'denies member to complete task assigned to someone else' do
      other_assigned_task = create(:task, creator: other_member, assignee: other_member)
      expect(subject.new(member, other_assigned_task).complete?).to be false
    end
  end

  describe 'edge cases' do
    it 'handles nil user gracefully' do
      expect { subject.new(nil, task).show? }.to raise_error(NoMethodError)
    end

    it 'handles nil task gracefully' do
      expect(subject.new(admin, nil).show?).to be false
    end
  end

  describe TaskPolicy::Scope do
    let(:admin) { create(:user, :admin) }
    let(:manager) { create(:user, :manager) }
    let(:member) { create(:user, :member) }
    let!(:member_task) { create(:task, creator: member) }
    let!(:other_task) { create(:task, creator: create(:user)) }
    let!(:assigned_task) { create(:task, creator: create(:user), assignee: member) }

    it 'returns all tasks for admin' do
      resolved = TaskPolicy::Scope.new(admin, Task).resolve
      expect(resolved).to include(member_task, other_task, assigned_task)
    end

    it 'returns all tasks for manager' do
      resolved = TaskPolicy::Scope.new(manager, Task).resolve
      expect(resolved).to include(member_task, other_task, assigned_task)
    end

    it 'returns only own tasks for member' do
      resolved = TaskPolicy::Scope.new(member, Task).resolve
      expect(resolved).to include(member_task)
      expect(resolved).to include(assigned_task) # Assigned tasks are also visible
      expect(resolved).not_to include(other_task)
    end

    it 'handles member with no tasks' do
      new_member = create(:user, :member)
      resolved = TaskPolicy::Scope.new(new_member, Task).resolve
      expect(resolved).to be_empty
    end

    it 'filters correctly with multiple tasks' do
      another_member = create(:user, :member)
      another_member_task = create(:task, creator: another_member)

      resolved = TaskPolicy::Scope.new(member, Task).resolve
      expect(resolved).to include(member_task)
      expect(resolved).not_to include(another_member_task)
    end
  end
end
