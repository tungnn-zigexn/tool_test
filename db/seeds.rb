# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# Create admin user by default
admin = User.find_or_initialize_by(email: "admin@zigexn.vn")
admin.assign_attributes(
  name: "Admin User",
  password: "password123",
  password_confirmation: "password123",
  role: :admin,
  provider: "local"
)
admin.save! if admin.new_record? || admin.changed?

puts "Admin user created/updated: #{admin.email}"

user = User.find_or_initialize_by(email: "user@zigexn.vn")
user.assign_attributes(
  name: "Regular User",
  password: "password123",
  password_confirmation: "password123",
  role: :user,
  provider: "local"
)
user.save! if user.new_record? || user.changed?

puts "Regular user created/updated: #{user.email}"

# Create sample projects
project1 = Project.find_or_create_by!(
  name: "Test Management System"
) do |p|
  p.description = "Hệ thống quản lý test cases và bugs"
end

project2 = Project.find_or_create_by!(
  name: "E-commerce Platform"
) do |p|
  p.description = "Nền tảng thương mại điện tử"
end

puts "Sample projects created: #{Project.count} projects"

# Create sample tasks for project 1
3.times do |i|
  Task.find_or_create_by!(
    project: project1,
    title: "Task #{i + 1} for #{project1.name}",
    status: [ "new", "in_progress", "resolved" ].sample
  ) do |t|
    t.description = "Mô tả cho task #{i + 1}"
    t.assignee = [ admin, user ].sample
  end
end

puts "Sample tasks created for projects"
puts "\n=== Seed completed ==="
puts "You can login with:"
puts "  Admin: admin@zigexn.vn / password123"
puts "  User: user@zigexn.vn / password123"
