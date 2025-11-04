require 'rails_helper'

RSpec.describe Comment, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:content) }

    context 'content validation' do
      it 'requires content presence' do
        comment = build(:comment, content: nil)
        expect(comment).not_to be_valid
        expect(comment.errors[:content]).to be_present
      end

      it 'requires content presence' do
        comment = build(:comment, content: '')
        expect(comment).not_to be_valid
      end

      it 'accepts valid content' do
        comment = build(:comment, content: 'This is a valid comment')
        expect(comment).to be_valid
      end

      it 'accepts long content' do
        long_content = 'a' * 1000
        comment = build(:comment, content: long_content)
        expect(comment).to be_valid
      end
    end
  end

  describe 'associations' do
    it { should belong_to(:task) }
    it { should belong_to(:user) }

    context 'task association' do
      it 'belongs to task' do
        task = create(:task)
        comment = create(:comment, task: task)
        expect(comment.task).to eq(task)
      end

      it 'requires task' do
        comment = build(:comment, task: nil)
        expect(comment).not_to be_valid
      end

      it 'destroys comment when task is destroyed' do
        task = create(:task)
        comment = create(:comment, task: task)
        expect { task.destroy }.to change { Comment.count }.by(-1)
      end
    end

    context 'user association' do
      it 'belongs to user' do
        user = create(:user)
        comment = create(:comment, user: user)
        expect(comment.user).to eq(user)
      end

      it 'requires user' do
        comment = build(:comment, user: nil)
        expect(comment).not_to be_valid
      end

      it 'destroys comment when user is destroyed' do
        user = create(:user)
        comment = create(:comment, user: user)
        expect { user.destroy }.to change { Comment.count }.by(-1)
      end
    end
  end

  describe 'timestamps' do
    it 'sets created_at on creation' do
      freeze_time do
        comment = create(:comment)
        expect(comment.created_at).to be_within(1.second).of(Time.current)
      end
    end

    it 'sets updated_at on creation' do
      freeze_time do
        comment = create(:comment)
        expect(comment.updated_at).to be_within(1.second).of(Time.current)
      end
    end

    it 'updates updated_at on modification' do
      comment = create(:comment)
      original_updated_at = comment.updated_at
      travel 1.hour do
        comment.update(content: 'Updated content')
        expect(comment.updated_at).to be > original_updated_at
      end
    end
  end
end
