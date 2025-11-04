FactoryBot.define do
  factory :comment do
    content { Faker::Lorem.paragraph }
    association :task
    association :user
  end
end
