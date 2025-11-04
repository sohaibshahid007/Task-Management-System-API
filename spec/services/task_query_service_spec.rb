require 'rails_helper'

RSpec.describe TaskQuery, type: :service do
  let(:admin) { create(:user, :admin) }
  let(:member) { create(:user, :member) }
  let(:other_member) { create(:user, :member) }

  before do
    # Create tasks for different users and statuses
    create(:task, creator: admin, status: :pending, priority: :high)
    create(:task, creator: admin, status: :completed, priority: :medium)
    create(:task, creator: member, status: :pending, priority: :low)
    create(:task, creator: member, assignee: member, status: :in_progress, priority: :high)
    create(:task, creator: other_member, status: :pending, priority: :urgent)
  end

  describe '.call' do
    context 'with admin user' do
      it 'returns all tasks' do
        params = ActionController::Parameters.new({})
        result = described_class.call(user: admin, params: params)

        expect(result).to be_success
        expect(result.data.count).to eq(5)
      end

      it 'filters by status' do
        params = ActionController::Parameters.new({ status: 'pending' })
        result = described_class.call(user: admin, params: params)

        expect(result).to be_success
        expect(result.data.count).to eq(3)
        expect(result.data.pluck(:status).uniq).to eq([ 'pending' ])
      end

      it 'filters by priority' do
        params = ActionController::Parameters.new({ priority: 'high' })
        result = described_class.call(user: admin, params: params)

        expect(result).to be_success
        expect(result.data.count).to eq(2)
        expect(result.data.pluck(:priority).uniq).to eq([ 'high' ])
      end

      it 'combines multiple filters' do
        params = ActionController::Parameters.new({ status: 'pending', priority: 'high' })
        result = described_class.call(user: admin, params: params)

        expect(result).to be_success
        expect(result.data.count).to eq(1)
      end
    end

    context 'with member user' do
      it 'returns only tasks created by or assigned to the member' do
        params = ActionController::Parameters.new({})
        result = described_class.call(user: member, params: params)

        expect(result).to be_success
        task_ids = result.data.pluck(:id)
        member_task_ids = (member.created_tasks.pluck(:id) + member.assigned_tasks.pluck(:id)).uniq
        expect(task_ids.sort).to eq(member_task_ids.sort)
      end

      it 'filters assigned_to_me tasks' do
        params = ActionController::Parameters.new({ assigned_to_me: 'true' })
        result = described_class.call(user: member, params: params)

        expect(result).to be_success
        expect(result.data.count).to eq(1)
        expect(result.data.first.assignee_id).to eq(member.id)
      end

      it 'filters created_by_me tasks' do
        params = ActionController::Parameters.new({ created_by_me: 'true' })
        result = described_class.call(user: member, params: params)

        expect(result).to be_success
        expect(result.data.pluck(:creator_id).uniq).to eq([ member.id ])
      end
    end

    context 'with no filters' do
      it 'returns base query without filtering' do
        params = ActionController::Parameters.new({})
        result = described_class.call(user: admin, params: params)

        expect(result).to be_success
        expect(result.data).to be_a(ActiveRecord::Relation)
      end
    end
  end
end
