# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

puts "=== Resetting Database Data ==="
# Model order matters for delete_all due to foreign keys if they are enforced (sqlite usually isn't unless PRAGMA is on)
# We use delete_all for speed as we are clearing everything.
models = [
  BugComment, BugEvidence, NotificationRead, ActivityLog, 
  DailyImportRun, TestResult, TestRun, Bug, TestStepContent, 
  TestStep, TestCase, Task, Project, Notification, User
]

models.each do |model|
  puts "Deleting #{model.name} records..."
  model.delete_all
end

# Reset SQLite sequence (IDs back to 1)
tables = %w[
  bug_comments bug_evidences notification_reads activity_logs 
  daily_import_runs test_results test_runs bugs test_step_contents 
  test_steps test_cases tasks projects notifications users
]

tables.each do |table_name|
  ActiveRecord::Base.connection.execute("DELETE FROM sqlite_sequence WHERE name='#{table_name}'")
end
puts "Database tables cleared and ID sequences reset."

puts "\n=== Creating Default Projects ==="
project_names = ["ChukosyaEx V2", "New Sell Car", "TCV", "Usedcar-EX"]
project_names.each do |name|
  Project.create!(name: name)
  puts "Created project: #{name}"
end

puts "\n=== Seeding Users ==="
default_password = "123456"

# 1. Admin User
admin_email = "admin@zigexn.vn"
admin = User.create!(
  name: "admin",
  email: admin_email,
  password: default_password,
  password_confirmation: default_password,
  role: :admin,
  provider: "local"
)
puts "Admin seeded: #{admin_email}"

# 2. Regular Users
users_list = [
  { name: "Chien Do", email: "chiendv@zigexn.vn" },
  { name: "Hiệp Phan Văn", email: "hieppv@zigexn.vn" },
  { name: "Hung Dam Tien", email: "hungdt@zigexn.vn" },
  { name: "Huy Bùi Quang", email: "huybq@zigexn.vn" },
  { name: "Hien Phan Thi", email: "hienpt@zigexn.vn" },
  { name: "Nhan Dang Thanh", email: "nhandangthanh@zigexn.vn" },
  { name: "Phong Nguyen Tien", email: "phongnt1@zigexn.vn" },
  { name: "Phong Pham Thanh", email: "phongphamthanh@zigexn.vn" },
  { name: "Quan Vu Minh", email: "quanvuminh@zigexn.vn" },
  { name: "Thang Nguyen Duc", email: "thangnd@zigexn.vn" },
  { name: "Thanh Nguyen Thi", email: "thanhnt@zigexn.vn" },
  { name: "Thien Doan Hoang", email: "thiendh@zigexn.vn" },
  { name: "Tri Nguyen Phan Minh", email: "trinpm@zigexn.vn" },
  { name: "Truong Tran Xuan", email: "truongtx@zigexn.vn" },
  { name: "Tung Nguyen Ngoc", email: "tungnguyenngoc@zigexn.vn" },
  { name: "Vinh Nguyen Hoang", email: "vinhnh@zigexn.vn" },
  { name: "Đạt Đỗ", email: "datdg@zigexn.vn" }
]

users_list.each do |u|
  User.create!(
    name: u[:name],
    email: u[:email],
    password: default_password,
    password_confirmation: default_password,
    role: :user,
    provider: "local"
  )
  puts "User seeded: #{u[:email]} (#{u[:name]})"
end

puts "\n=== Seed completed ==="
puts "Total Projects: #{Project.count}"
puts "Total Users: #{User.count}"
