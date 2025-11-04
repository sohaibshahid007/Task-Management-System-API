# Clear existing data
User.destroy_all
Task.destroy_all
Comment.destroy_all

puts "Creating users..."

# Create admin user
admin = User.create!(
  email: 'admin@example.com',
  password: 'password123',
  password_confirmation: 'password123',
  first_name: 'Admin',
  last_name: 'User',
  role: :admin
)

# Create manager users
manager1 = User.create!(
  email: 'manager1@example.com',
  password: 'password123',
  password_confirmation: 'password123',
  first_name: 'Manager',
  last_name: 'One',
  role: :manager
)

manager2 = User.create!(
  email: 'manager2@example.com',
  password: 'password123',
  password_confirmation: 'password123',
  first_name: 'Manager',
  last_name: 'Two',
  role: :manager
)

# Create member users
member1 = User.create!(
  email: 'member1@example.com',
  password: 'password123',
  password_confirmation: 'password123',
  first_name: 'Member',
  last_name: 'One',
  role: :member
)

member2 = User.create!(
  email: 'member2@example.com',
  password: 'password123',
  password_confirmation: 'password123',
  first_name: 'Member',
  last_name: 'Two',
  role: :member
)

member3 = User.create!(
  email: 'member3@example.com',
  password: 'password123',
  password_confirmation: 'password123',
  first_name: 'Member',
  last_name: 'Three',
  role: :member
)

users = [ admin, manager1, manager2, member1, member2, member3 ]

puts "Creating tasks..."

# Create tasks with various statuses and priorities
20.times do |i|
  task = Task.create!(
    title: "Task #{i + 1}: Important project milestone",
    description: "This is a detailed description for task #{i + 1}. It includes important information about the task requirements and deliverables.",
    status: [ :pending, :in_progress, :completed, :archived ].sample,
    priority: [ :low, :medium, :high, :urgent ].sample,
    due_date: rand(1..30).days.from_now,
    creator: users.sample,
    assignee: users.sample
  )

  # Set completed_at if task is completed
  task.update(completed_at: rand(1..60).days.ago) if task.completed?

  # Create comments for some tasks
  if rand < 0.6 # 60% of tasks have comments
    rand(1..3).times do
      Comment.create!(
        content: "This is a comment on task #{task.title}. It provides additional context and feedback.",
        task: task,
        user: users.sample
      )
    end
  end
end

# Create some overdue tasks
5.times do |i|
  Task.create!(
    title: "Overdue Task #{i + 1}",
    description: "This task is overdue and needs immediate attention.",
    status: [ :pending, :in_progress ].sample,
    priority: [ :medium, :high, :urgent ].sample,
    due_date: rand(1..10).days.ago,
    creator: users.sample,
    assignee: users.sample
  )
end

# Create some high priority tasks
5.times do |i|
  Task.create!(
    title: "High Priority Task #{i + 1}",
    description: "This is a high priority task that requires urgent completion.",
    status: [ :pending, :in_progress ].sample,
    priority: [ :high, :urgent ].sample,
    due_date: rand(1..7).days.from_now,
    creator: users.sample,
    assignee: users.sample
  )
end

puts "Seeding completed!"
puts "Created #{User.count} users"
puts "Created #{Task.count} tasks"
puts "Created #{Comment.count} comments"

puts "\nLogin credentials:"
puts "Admin: admin@example.com / password123"
puts "Manager: manager1@example.com / password123"
puts "Member: member1@example.com / password123"
