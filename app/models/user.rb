class User < ApplicationRecord
  # Associations
  has_many :assigned_tasks, class_name: 'Task', foreign_key: 'assignee_id', dependent: :nullify
  has_many :created_test_cases, class_name: 'TestCase', foreign_key: 'created_by_id', dependent: :nullify
  has_many :test_runs, foreign_key: 'executed_by_id', dependent: :nullify
  has_many :test_results, foreign_key: 'executed_by_id', dependent: :nullify
  has_many :dev_bugs, class_name: 'Bug', foreign_key: 'dev_id', dependent: :nullify
  has_many :tester_bugs, class_name: 'Bug', foreign_key: 'tester_id', dependent: :nullify
  has_many :test_case_histories
  has_many :task_histories

  # Authentication (local password)
  has_secure_password validations: true

  # Provider enum
  enum provider: { local: 'local', google: 'google' }

  # Role enum
  enum role: { admin: 'admin', tester: 'tester', developer: 'developer' }

  # Validations
  validates :email, presence: true, uniqueness: true
  validates :provider, presence: true
  validates :role, presence: true

  # Soft delete
  scope :active, -> { where(deleted_at: nil) }
  scope :deleted, -> { where.not(deleted_at: nil) }

  def soft_delete!
    update!(deleted_at: Time.current)
  end

  def active?
    deleted_at.nil?
  end

  # Google OAuth
  def self.from_google(auth)
    where(provider: 'google', email: auth.info.email).first_or_initialize.tap do |user|
      user.name   = auth.info.name
      user.avatar = auth.info.image
      user.save!
    end
  end
end
