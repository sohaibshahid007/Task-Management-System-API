require 'rails_helper'

RSpec.describe UserPolicy, type: :policy do
  subject { described_class }

  let(:admin) { create(:user, :admin) }
  let(:manager) { create(:user, :manager) }
  let(:member) { create(:user, :member) }
  let(:other_user) { create(:user, :member) }

  describe '#index?' do
    it 'allows admin to list users' do
      expect(subject.new(admin, User).index?).to be true
    end

    it 'allows manager to list users' do
      expect(subject.new(manager, User).index?).to be true
    end

    it 'denies member to list users' do
      expect(subject.new(member, User).index?).to be false
    end
  end

  describe '#show?' do
    it 'allows admin to view any user' do
      expect(subject.new(admin, other_user).show?).to be true
    end

    it 'allows manager to view any user' do
      expect(subject.new(manager, other_user).show?).to be true
    end

    it 'allows user to view own profile' do
      expect(subject.new(member, member).show?).to be true
    end

    it 'denies member to view other users' do
      expect(subject.new(member, other_user).show?).to be false
    end
  end

  describe '#create?' do
    it 'allows admin to create users' do
      expect(subject.new(admin, User).create?).to be true
    end

    it 'denies manager to create users' do
      expect(subject.new(manager, User).create?).to be false
    end

    it 'denies member to create users' do
      expect(subject.new(member, User).create?).to be false
    end
  end

  describe '#update?' do
    it 'allows admin to update any user' do
      expect(subject.new(admin, other_user).update?).to be true
    end

    it 'allows user to update own profile' do
      expect(subject.new(member, member).update?).to be true
    end

    it 'denies member to update other users' do
      expect(subject.new(member, other_user).update?).to be false
    end
  end

  describe '#destroy?' do
    it 'allows admin to delete users' do
      expect(subject.new(admin, other_user).destroy?).to be true
    end

    it 'denies manager to delete users' do
      expect(subject.new(manager, other_user).destroy?).to be false
    end

    it 'denies member to delete users' do
      expect(subject.new(member, other_user).destroy?).to be false
    end
  end

  describe 'self-modification permissions' do
    it 'allows user to view own profile' do
      expect(subject.new(member, member).show?).to be true
    end

    it 'allows user to update own profile' do
      expect(subject.new(member, member).update?).to be true
    end

    it 'denies user to delete own account' do
      expect(subject.new(member, member).destroy?).to be false
    end

    it 'allows admin to view own profile' do
      expect(subject.new(admin, admin).show?).to be true
    end

    it 'allows admin to update own profile' do
      expect(subject.new(admin, admin).update?).to be true
    end

    it 'denies admin to delete own account' do
      expect(subject.new(admin, admin).destroy?).to be true
    end
  end

  describe 'edge cases' do
    it 'handles nil user gracefully' do
      expect { subject.new(nil, other_user).show? }.to raise_error(NoMethodError)
    end

    it 'handles nil record gracefully' do
      expect(subject.new(admin, nil).show?).to be false
    end
  end

  describe UserPolicy::Scope do
    let(:admin) { create(:user, :admin) }
    let(:manager) { create(:user, :manager) }
    let(:member) { create(:user, :member) }
    let!(:other_user) { create(:user, :member) }

    it 'returns all users for admin' do
      resolved = UserPolicy::Scope.new(admin, User).resolve
      expect(resolved).to include(admin, manager, member, other_user)
    end

    it 'returns all users for manager' do
      resolved = UserPolicy::Scope.new(manager, User).resolve
      expect(resolved).to include(admin, manager, member, other_user)
    end

    it 'returns no users for member' do
      resolved = UserPolicy::Scope.new(member, User).resolve
      expect(resolved).to be_empty
    end

    it 'handles empty database' do
      User.destroy_all
      new_admin = create(:user, :admin)
      resolved = UserPolicy::Scope.new(new_admin, User).resolve
      expect(resolved).to include(new_admin)
    end
  end
end
