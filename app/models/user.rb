class User < ApplicationRecord
  include SoftDeletable

  # Devise modules
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # Associations
  has_many :assigned_tasks, class_name: 'Task', foreign_key: 'assignee_id', dependent: :nullify
  has_many :created_test_cases, class_name: 'TestCase', foreign_key: 'created_by_id', dependent: :nullify
  has_many :test_runs, foreign_key: 'executed_by_id', dependent: :nullify
  has_many :test_results, foreign_key: 'executed_by_id', dependent: :nullify
  has_many :dev_bugs, class_name: 'Bug', foreign_key: 'dev_id', dependent: :nullify
  has_many :tester_bugs, class_name: 'Bug', foreign_key: 'tester_id', dependent: :nullify
  has_many :test_case_histories
  has_many :task_histories

  # Enum for roles: 0 = admin, 1 = user
  enum :role, { admin: 0, user: 1, developer: 2 }, default: :user

  # Validations
  validates :email, presence: true, uniqueness: true, format: {
    with: /@zigexn\.vn\z/,
    message: 'must have @zigexn.vn'
  }
  validates :provider, presence: true
  validates :role, presence: true

  # Google OAuth
  def self.from_google(auth)
    # Only allow email @zigexn.vn
    return nil unless auth.info.email.end_with?('@zigexn.vn')

    where(provider: 'google', email: auth.info.email).first_or_initialize.tap do |user|
      user.name   = auth.info.name
      user.avatar = auth.info.image
      user.role   = :user if user.new_record?
      user.save!
    end
  end
end
