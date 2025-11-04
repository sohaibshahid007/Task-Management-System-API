require 'rails_helper'

RSpec.describe Task, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:title) }
    it { should validate_presence_of(:status) }
    it { should validate_presence_of(:priority) }
  end

  describe 'associations' do
    it { should belong_to(:creator).class_name('User') }
    it { should belong_to(:assignee).class_name('User').optional }
    it { should have_many(:comments).dependent(:destroy) }
  end

  describe 'enums' do
    it { should define_enum_for(:status).with_values(pending: 0, in_progress: 1, completed: 2, archived: 3) }
    it { should define_enum_for(:priority).with_values(low: 0, medium: 1, high: 2, urgent: 3) }
  end

  describe 'scopes' do
    let!(:pending_task) { create(:task, status: :pending) }
    let!(:completed_task) { create(:task, :completed) }
    let!(:high_priority_task) { create(:task, :high_priority) }
    let!(:overdue_task) { create(:task, :overdue) }
    let(:user) { create(:user) }
    let!(:assigned_task) { create(:task, assignee: user) }

    describe '.by_status' do
      it 'filters tasks by status' do
        expect(Task.by_status(:pending)).to include(pending_task)
        expect(Task.by_status(:pending)).not_to include(completed_task)
      end
    end

    describe '.by_priority' do
      it 'filters tasks by priority' do
        expect(Task.by_priority(:high)).to include(high_priority_task)
      end
    end

    describe '.overdue' do
      it 'returns overdue tasks' do
        expect(Task.overdue).to include(overdue_task)
      end
    end

    describe '.assigned_to' do
      it 'returns tasks assigned to user' do
        expect(Task.assigned_to(user)).to include(assigned_task)
      end
    end

    describe '.recent' do
      it 'orders tasks by created_at desc' do
        tasks = Task.recent
        expect(tasks.first.created_at).to be >= tasks.last.created_at
      end
    end

    describe '.high_priority' do
      it 'returns high or urgent priority tasks' do
        expect(Task.high_priority).to include(high_priority_task)
      end
    end

    describe '.upcoming' do
      let!(:upcoming_task) { create(:task, due_date: 3.days.from_now) }
      let!(:past_task) { create(:task, due_date: 1.day.ago) }

      it 'returns tasks due within specified days' do
        expect(Task.upcoming(7)).to include(upcoming_task)
        expect(Task.upcoming(7)).not_to include(past_task)
      end
    end

    describe '.completed_between' do
      let(:start_date) { 5.days.ago.beginning_of_day }
      let(:end_date) { Time.current.end_of_day }
      let!(:completed_task) { create(:task, :completed, completed_at: 3.days.ago) }
      let!(:old_completed_task) { create(:task, :completed, completed_at: 10.days.ago) }

      it 'returns tasks completed in date range' do
        result_ids = Task.completed_between(start_date, end_date).pluck(:id)
        expect(result_ids).to include(completed_task.id)
        expect(Task.completed_between(start_date, end_date).count).to be > 0
      end
    end

    describe '.created_by' do
      let(:creator) { create(:user) }
      let!(:creator_task) { create(:task, creator: creator) }

      it 'returns tasks created by specific user' do
        expect(Task.created_by(creator)).to include(creator_task)
      end
    end
  end

  describe '#overdue?' do
    it 'returns true for overdue tasks' do
      task = build(:task, due_date: 1.day.ago, status: :pending)
      expect(task.overdue?).to be true
    end

    it 'returns false for completed tasks' do
      task = build(:task, :completed, due_date: 1.day.ago)
      expect(task.overdue?).to be false
    end
  end

  describe 'callbacks' do
    it 'sets completed_at when status changes to completed' do
      task = create(:task, status: :pending)
      freeze_time do
        task.update(status: :completed)
        expect(task.completed_at).to be_within(1.second).of(Time.current)
      end
    end

    it 'clears completed_at when status changes from completed' do
      task = create(:task, :completed)
      task.update(status: :pending)
      expect(task.completed_at).to be_nil
    end

    it 'does not set completed_at when status changes to in_progress' do
      task = create(:task, status: :pending)
      task.update(status: :in_progress)
      expect(task.completed_at).to be_nil
    end

    it 'preserves completed_at when updating other attributes while completed' do
      task = create(:task, :completed)
      original_completed_at = task.completed_at
      task.update(title: 'Updated Title')
      expect(task.reload.completed_at).to eq(original_completed_at)
    end
  end

  describe 'status transitions' do
    it 'allows transition from pending to in_progress' do
      task = create(:task, status: :pending)
      expect { task.update(status: :in_progress) }.to change { task.status }.to('in_progress')
    end

    it 'allows transition from in_progress to completed' do
      task = create(:task, status: :in_progress)
      expect { task.update(status: :completed) }.to change { task.status }.to('completed')
    end

    it 'allows transition from completed to archived' do
      task = create(:task, :completed)
      expect { task.update(status: :archived) }.to change { task.status }.to('archived')
    end

    it 'allows transition from any status to pending' do
      task = create(:task, :completed)
      expect { task.update(status: :pending) }.to change { task.status }.to('pending')
    end
  end

  describe '#assignee_name' do
    it 'returns assignee full name when assignee exists' do
      assignee = create(:user, first_name: 'John', last_name: 'Doe')
      task = create(:task, assignee: assignee)
      expect(task.assignee_name).to eq('John Doe')
    end

    it 'returns nil when assignee is nil' do
      task = create(:task, assignee: nil)
      expect(task.assignee_name).to be_nil
    end
  end

  describe '#creator_name' do
    it 'returns creator full name' do
      creator = create(:user, first_name: 'Jane', last_name: 'Smith')
      task = create(:task, creator: creator)
      expect(task.creator_name).to eq('Jane Smith')
    end
  end

  describe 'validations' do
    context 'title validation' do
      it 'requires title presence' do
        task = build(:task, title: nil)
        expect(task).not_to be_valid
        expect(task.errors[:title]).to be_present
      end

      it 'accepts valid title' do
        task = build(:task, title: 'Valid Title')
        expect(task).to be_valid
      end
    end

    context 'status validation' do
      it 'requires status presence' do
        task = build(:task, status: nil)
        expect(task).not_to be_valid
        expect(task.errors[:status]).to be_present
      end

      it 'accepts valid status values' do
        %i[pending in_progress completed archived].each do |status|
          task = build(:task, status: status)
          expect(task).to be_valid
        end
      end
    end

    context 'priority validation' do
      it 'requires priority presence' do
        task = build(:task, priority: nil)
        expect(task).not_to be_valid
        expect(task.errors[:priority]).to be_present
      end

      it 'accepts valid priority values' do
        %i[low medium high urgent].each do |priority|
          task = build(:task, priority: priority)
          expect(task).to be_valid
        end
      end
    end
  end

  describe 'associations' do
    context 'creator association' do
      it 'belongs to creator' do
        creator = create(:user)
        task = create(:task, creator: creator)
        expect(task.creator).to eq(creator)
      end

      it 'requires creator' do
        task = build(:task, creator: nil)
        expect(task).not_to be_valid
      end
    end

    context 'assignee association' do
      it 'belongs to assignee (optional)' do
        assignee = create(:user)
        task = create(:task, assignee: assignee)
        expect(task.assignee).to eq(assignee)
      end

      it 'allows nil assignee' do
        task = build(:task, assignee: nil)
        expect(task).to be_valid
      end
    end

    context 'comments association' do
      it 'has many comments' do
        task = create(:task)
        comment1 = create(:comment, task: task)
        comment2 = create(:comment, task: task)
        expect(task.comments).to include(comment1, comment2)
      end

      it 'destroys comments when task is destroyed' do
        task = create(:task)
        comment = create(:comment, task: task)
        expect { task.destroy }.to change { Comment.count }.by(-1)
      end
    end
  end
end
