# Thiết lập Authentication và Authorization

## Tổng quan

Dự án sử dụng **Devise** cho authentication và **CanCanCan** cho authorization.

## Cấu hình

### 1. User Model

User model đã được cấu hình với:
- **Devise modules**: `database_authenticatable`, `registerable`, `recoverable`, `rememberable`, `validatable`
- **Roles**: Sử dụng enum với 3 roles
  - `admin` (0): Có toàn quyền quản trị
  - `user` (1): User thường (mặc định)
  - `developer` (2): Developer

### 2. Email Validation

Chỉ email có đuôi `@zigexn.vn` mới được phép đăng ký và đăng nhập.

```ruby
validates :email, format: {
  with: /@zigexn\.vn\z/,
  message: "phải có đuôi @zigexn.vn"
}
```

### 3. Quyền (Abilities)

Được định nghĩa trong `app/models/ability.rb`:

#### Admin (role = 0)
- Toàn quyền trên tất cả resources
- Có thể thêm, sửa, xóa Users
- Có thể thêm, sửa, xóa Projects

#### User/Developer (role = 1 hoặc 2)
- Có thể đọc: Projects, Tasks, TestCases, Bugs
- Có thể tạo và cập nhật: TestCases, TestRuns, TestResults, Bugs, BugComments
- **Không thể** xóa Users hoặc Projects

## Seed Data

Hai users mẫu đã được tạo trong `db/seeds.rb`:

1. **Admin User**
   - Email: `admin@zigexn.vn`
   - Password: `password123`
   - Role: admin

2. **Regular User**
   - Email: `user@zigexn.vn`
   - Password: `password123`
   - Role: user

## Sử dụng

### Đăng nhập

Truy cập: `http://localhost:4000/users/sign_in`

### Đăng ký (Register)

Truy cập: `http://localhost:4000/users/sign_up`

**Lưu ý**: Chỉ email có đuôi `@zigexn.vn` mới được chấp nhận.

### Đăng xuất

Truy cập: `http://localhost:4000/users/sign_out` (DELETE method)

## Authorization Checks

CanCanCan tự động kiểm tra quyền thông qua `ApplicationController`:

```ruby
load_and_authorize_resource unless: :devise_controller?
```

Nếu user không có quyền truy cập, sẽ bị redirect về trang chủ với thông báo lỗi.

## Chạy trong Docker

```bash
# Cài đặt dependencies
docker compose exec web bundle install

# Chạy migrations
docker compose exec web bundle exec rails db:migrate

# Tạo seed data
docker compose exec web bundle exec rails db:seed

# Restart web server
docker compose restart web
```

## Custom Authorization

Để kiểm tra quyền trong controller:

```ruby
# Kiểm tra quyền với action cụ thể
authorize! :create, Project

# Kiểm tra quyền trong view
<% if can? :update, @project %>
  <%= link_to "Edit", edit_project_path(@project) %>
<% end %>
```

## Thêm User mới (Admin only)

Admin có thể truy cập `/users` để:
- Xem danh sách users
- Tạo user mới
- Sửa thông tin user
- Xóa user

## Google OAuth (Optional)

Google OAuth vẫn được giữ lại trong routes. Cần cấu hình thêm nếu muốn sử dụng.


