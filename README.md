# Task Manager API

A comprehensive Ruby on Rails RESTful API for task management with role-based access control, background job processing, and comprehensive testing.

## Tech Stack

- **Ruby**: 3.2+
- **Rails**: 8.1+
- **Database**: PostgreSQL
- **Background Jobs**: Sidekiq
- **Cache/Queue**: Redis
- **Authentication**: Devise
- **Authorization**: Pundit
- **API Serialization**: JSONAPI::Serializer
- **Testing**: RSpec, FactoryBot, Faker

## Features

### Authentication & Authorization
- User authentication using Devise
- Email/password authentication
- Password reset functionality
- Token-based API authentication (simplified - use JWT in production)
- Role-based access control (Admin, Manager, Member)
- Pundit policies for fine-grained authorization

### Models
- **User**: Email, password, role (admin/manager/member), first_name, last_name
- **Task**: Title, description, status (pending/in_progress/completed/archived), priority (low/medium/high/urgent), due_date, creator, assignee
- **Comment**: Content, task, user

### API Features
- RESTful API with versioning (v1, v2)
- Comprehensive filtering and pagination
- Optimized queries with N+1 prevention
- Dashboard endpoint with aggregated statistics
- Error handling with consistent error format

### Service Objects
- **TaskCreationService**: Handles task creation with validation and notifications
- **TaskCompletionService**: Manages task completion with timestamp updates
- **TaskAssignmentService**: Handles task assignment with authorization checks

### Background Jobs (Sidekiq)
- **TaskNotificationJob**: Sends email notifications for task events
- **TaskReminderJob**: Daily reminders for tasks due in 24 hours
- **TaskArchivalJob**: Weekly archival of completed tasks older than 30 days
- **DataExportJob**: Generates CSV exports of user tasks

## Setup Instructions

### Prerequisites
- Ruby 3.2+
- Rails 8.1+
- PostgreSQL
- Redis

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd task_manager_api
   ```

2. **Install dependencies**
   ```bash
   bundle install
   ```

3. **Set up the database**
   ```bash
   rails db:create
   rails db:migrate
   rails db:seed
   ```

4. **Start Redis** (required for Sidekiq)
   ```bash
   redis-server
   ```

5. **Start Sidekiq** (in a separate terminal)
   ```bash
   bundle exec sidekiq
   ```

6. **Start the Rails server**
   ```bash
   rails server
   ```

The API will be available at `http://localhost:3000`

## Database Setup

### Seed Data
The seed file creates:
- 1 Admin user
- 2 Manager users
- 3 Member users
- 30+ Tasks with various statuses and priorities
- Comments on multiple tasks

**Default Login Credentials:**
- Admin: `admin@example.com` / `password123`
- Manager: `manager1@example.com` / `password123`
- Member: `member1@example.com` / `password123`

## API Documentation

### Authentication

All API endpoints (except auth endpoints) require authentication via Bearer token in the Authorization header:
```
Authorization: Bearer <user_email>
```

**Note**: This is a simplified token implementation. In production, use JWT or similar secure token system.

### API Endpoints

#### Authentication
- `POST /api/v1/auth/login` - Login with email/password
- `POST /api/v1/auth/signup` - Create new user account
- `POST /api/v1/auth/logout` - Logout
- `POST /api/v1/auth/password/reset` - Request password reset

#### Users
- `GET /api/v1/users` - List users (admin/manager only)
- `GET /api/v1/users/:id` - Show user profile
- `PATCH /api/v1/users/:id` - Update user
- `DELETE /api/v1/users/:id` - Delete user (admin only)

#### Tasks
- `GET /api/v1/tasks` - List tasks (filtered by role)
- `POST /api/v1/tasks` - Create task
- `GET /api/v1/tasks/:id` - Show task details
- `PATCH /api/v1/tasks/:id` - Update task
- `DELETE /api/v1/tasks/:id` - Delete task (admin only)
- `POST /api/v1/tasks/:id/assign` - Assign task to user
- `POST /api/v1/tasks/:id/complete` - Mark task complete
- `GET /api/v1/tasks/dashboard` - Dashboard stats (optimized queries)
- `GET /api/v1/tasks/overdue` - List overdue tasks
- `POST /api/v1/tasks/:id/export` - Trigger export job

#### Comments
- `GET /api/v1/tasks/:task_id/comments` - List comments for a task
- `POST /api/v1/tasks/:task_id/comments` - Create comment
- `DELETE /api/v1/tasks/:task_id/comments/:id` - Delete comment

### Query Parameters

**Tasks Index:**
- `status` - Filter by status (pending, in_progress, completed, archived)
- `priority` - Filter by priority (low, medium, high, urgent)
- `assigned_to_me` - Filter tasks assigned to current user (true/false)
- `created_by_me` - Filter tasks created by current user (true/false)
- `page` - Page number (default: 1)
- `per_page` - Items per page (default: 20)

### Example Requests

**Login:**
```bash
curl -X POST http://localhost:3000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@example.com","password":"password123"}'
```

**Create Task:**
```bash
curl -X POST http://localhost:3000/api/v1/tasks \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer admin@example.com" \
  -d '{
    "task": {
      "title": "New Task",
      "description": "Task description",
      "priority": "high",
      "due_date": "2025-12-01"
    }
  }'
```

**Get Dashboard:**
```bash
curl -X GET http://localhost:3000/api/v1/tasks/dashboard \
  -H "Authorization: Bearer admin@example.com"
```

## Role-Based Permissions

| Action | Admin | Manager | Member |
|--------|-------|---------|--------|
| Create Tasks | ✓ | ✓ | ✓ |
| Edit Own Tasks | ✓ | ✓ | ✓ |
| Edit Any Task | ✓ | ✓ | ✗ |
| Delete Any Task | ✓ | ✗ | ✗ |
| Assign Tasks | ✓ | ✓ | ✗ |
| View All Tasks | ✓ | ✓ | Own only |

## Testing

### Run Tests
```bash
# Run all tests
bundle exec rspec

# Run with coverage
COVERAGE=true bundle exec rspec

# Run specific test file
bundle exec rspec spec/models/task_spec.rb
```

### Test Coverage
The test suite includes:
- Model tests (validations, associations, scopes, callbacks)
- Policy tests (authorization for all roles)
- Service tests (business logic)
- Job tests (background processing)
- Request tests (API endpoints)

### Test Structure
- `spec/models/` - Model tests
- `spec/policies/` - Policy tests
- `spec/services/` - Service object tests
- `spec/jobs/` - Background job tests
- `spec/requests/` - API endpoint tests
- `spec/factories/` - FactoryBot factories

## Background Jobs

### Sidekiq Configuration
Sidekiq is configured with multiple queues:
- `default` - General notifications
- `notifications` - Task reminders
- `low_priority` - Archival tasks
- `exports` - Data export jobs

### Scheduled Jobs
Configure cron jobs in `config/schedule.rb` or use Sidekiq-Cron:
- Daily: TaskReminderJob (tasks due in 24 hours)
- Weekly: TaskArchivalJob (archive old completed tasks)

## Database Schema

### Users
- `email` (string, unique, required)
- `encrypted_password` (string, Devise)
- `role` (enum: member=0, manager=1, admin=2)
- `first_name` (string, required)
- `last_name` (string, required)
- `timestamps`

### Tasks
- `title` (string, required)
- `description` (text)
- `status` (enum: pending=0, in_progress=1, completed=2, archived=3)
- `priority` (enum: low=0, medium=1, high=2, urgent=3)
- `due_date` (datetime)
- `creator_id` (references User, required)
- `assignee_id` (references User, optional)
- `completed_at` (datetime)
- `timestamps`

### Comments
- `content` (text, required)
- `task_id` (references Task, required)
- `user_id` (references User, required)
- `timestamps`

## Query Optimization

The application implements several query optimization techniques:
- **Eager Loading**: Uses `includes` to prevent N+1 queries
- **Indexes**: Added on frequently queried fields (status, priority, due_date, creator_id, assignee_id)
- **Scopes**: Reusable query chains for common filters
- **Counter Caches**: Available for task counts (counter_culture gem)

## API Versioning

The API uses URL path versioning:
- `/api/v1/*` - Version 1 (snake_case responses)
- `/api/v2/*` - Version 2 (camelCase responses - breaking change)

## Error Handling

All errors follow a consistent format:
```json
{
  "error": {
    "code": "ERROR_CODE",
    "message": "Human-readable error message",
    "details": {}
  }
}
```

## Development

### Code Quality
- Rubocop for code style
- Brakeman for security scanning
- Bullet gem for N+1 query detection

### Environment Variables
Create a `.env` file for local development (not committed):
```
DATABASE_URL=postgresql://localhost/task_manager_api_development
REDIS_URL=redis://localhost:6379/0
```

## Production Considerations

1. **Authentication**: Replace simplified token system with JWT
2. **Rate Limiting**: Configure rack-attack for production
3. **CORS**: Configure CORS for your frontend domain
4. **Email**: Configure ActionMailer for production email delivery
5. **Monitoring**: Set up error tracking (e.g., Sentry)
6. **Caching**: Configure Redis caching for production
7. **Background Jobs**: Use Sidekiq Pro/Enterprise for production features

## Architecture Decisions

### Service Objects
Service objects encapsulate complex business logic and provide:
- Consistent result objects
- Single responsibility
- Easy testing
- Reusable business logic

### Policy Objects
Pundit policies provide:
- Centralized authorization logic
- Policy scopes for role-based filtering
- Easy to test and maintain

### Background Jobs
Sidekiq jobs handle:
- Asynchronous email delivery
- Scheduled tasks
- Long-running operations
- Batch processing

## License

This project is part of a technical assessment.

## Author

Built as a technical assessment for a Senior Ruby on Rails Developer position.
