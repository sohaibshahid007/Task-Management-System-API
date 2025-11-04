require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:email) }
    it { should validate_presence_of(:first_name) }
    it { should validate_presence_of(:last_name) }
    it { should validate_uniqueness_of(:email).case_insensitive }

    context 'email format validation' do
      it 'accepts valid email addresses' do
        user = build(:user, email: 'valid@example.com')
        expect(user).to be_valid
      end

      it 'rejects invalid email addresses' do
        user = build(:user, email: 'invalid-email')
        expect(user).not_to be_valid
        expect(user.errors[:email]).to be_present
      end

      it 'rejects email without @ symbol' do
        user = build(:user, email: 'invalidemail.com')
        expect(user).not_to be_valid
      end

      it 'rejects email without domain' do
        user = build(:user, email: 'invalid@')
        expect(user).not_to be_valid
      end
    end

    context 'email case insensitivity' do
      it 'normalizes email to lowercase' do
        user = create(:user, email: 'Test@Example.COM')
        expect(user.email).to eq('test@example.com')
      end

      it 'prevents duplicate emails with different cases' do
        create(:user, email: 'test@example.com')
        duplicate = build(:user, email: 'TEST@EXAMPLE.COM')
        expect(duplicate).not_to be_valid
      end
    end
  end

  describe 'associations' do
    it { should have_many(:created_tasks).class_name('Task').with_foreign_key('creator_id') }
    it { should have_many(:assigned_tasks).class_name('Task').with_foreign_key('assignee_id') }
    it { should have_many(:comments) }

    context 'dependent destroy behavior' do
      let(:user) { create(:user) }

      it 'destroys created tasks when user is destroyed' do
        task = create(:task, creator: user)
        expect { user.destroy }.to change { Task.count }.by(-1)
      end

      it 'destroys comments when user is destroyed' do
        comment = create(:comment, user: user)
        expect { user.destroy }.to change { Comment.count }.by(-1)
      end

      it 'nullifies assignee_id when user is destroyed' do
        task = create(:task, assignee: user)
        user.destroy
        expect(task.reload.assignee_id).to be_nil
      end
    end
  end

  describe 'enums' do
    it { should define_enum_for(:role).with_values(member: 0, manager: 1, admin: 2) }

    context 'role enum behavior' do
      it 'allows setting role to member' do
        user = create(:user, role: :member)
        expect(user.role).to eq('member')
        expect(user.member?).to be true
      end

      it 'allows setting role to manager' do
        user = create(:user, role: :manager)
        expect(user.role).to eq('manager')
        expect(user.manager?).to be true
      end

      it 'allows setting role to admin' do
        user = create(:user, role: :admin)
        expect(user.role).to eq('admin')
        expect(user.admin?).to be true
      end

      it 'rejects invalid role values' do
        expect { create(:user, role: :invalid) }.to raise_error(ArgumentError)
      end
    end
  end

  describe '#full_name' do
    let(:user) { create(:user, first_name: 'John', last_name: 'Doe') }

    it 'returns the full name' do
      expect(user.full_name).to eq('John Doe')
    end

    it 'handles names with spaces' do
      user = create(:user, first_name: 'Mary Jane', last_name: 'Watson')
      expect(user.full_name).to eq('Mary Jane Watson')
    end

    it 'handles single character names' do
      user = create(:user, first_name: 'A', last_name: 'B')
      expect(user.full_name).to eq('A B')
    end
  end

  describe '#admin?' do
    it 'returns true for admin users' do
      admin = create(:user, :admin)
      expect(admin.admin?).to be true
    end

    it 'returns false for non-admin users' do
      member = create(:user, :member)
      expect(member.admin?).to be false
    end

    it 'returns false for manager users' do
      manager = create(:user, :manager)
      expect(manager.admin?).to be false
    end
  end

  describe '#manager?' do
    it 'returns true for manager users' do
      manager = create(:user, :manager)
      expect(manager.manager?).to be true
    end

    it 'returns false for admin users' do
      admin = create(:user, :admin)
      expect(admin.manager?).to be false
    end

    it 'returns false for member users' do
      member = create(:user, :member)
      expect(member.manager?).to be false
    end
  end

  describe '#member?' do
    it 'returns true for member users' do
      member = create(:user, :member)
      expect(member.member?).to be true
    end

    it 'returns false for admin users' do
      admin = create(:user, :admin)
      expect(admin.member?).to be false
    end

    it 'returns false for manager users' do
      manager = create(:user, :manager)
      expect(manager.member?).to be false
    end
  end
end
