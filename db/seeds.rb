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
