FactoryBot.define do
  factory :task do
    title { Faker::Lorem.sentence(word_count: 3) }
    description { Faker::Lorem.paragraph }
    status { :pending }
    priority { :medium }
    due_date { 7.days.from_now }
    association :creator, factory: :user
    association :assignee, factory: :user

    trait :pending do
      status { :pending }
    end

    trait :in_progress do
      status { :in_progress }
    end

    trait :completed do
      status { :completed }
      completed_at { Time.current }
    end

    trait :archived do
      status { :archived }
    end

    trait :high_priority do
      priority { :high }
    end

    trait :urgent do
      priority { :urgent }
    end

    trait :overdue do
      due_date { 1.day.ago }
      status { :pending }
    end
  end
end
