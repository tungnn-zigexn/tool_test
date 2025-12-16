class Task < ApplicationRecord
  belongs_to :project
  belongs_to :assignee, class_name: 'User', foreign_key: 'assignee_id', optional: true
  belongs_to :parent, class_name: 'Task', foreign_key: 'parent_id', optional: true

  has_many :subtasks, class_name: 'Task', foreign_key: 'parent_id', dependent: :destroy
  has_many :test_cases, dependent: :destroy
  has_many :test_runs, dependent: :destroy
  has_many :bugs, dependent: :destroy

  validates :title, presence: true

  scope :active, -> { where(deleted_at: nil) }
  scope :deleted, -> { where.not(deleted_at: nil) }
  scope :root_tasks, -> { where(parent_id: nil) }

  def soft_delete!
    update!(deleted_at: Time.current)
  end

  def active?
    deleted_at.nil?
  end

  def subtask?
    parent_id.present?
  end

  def root_task?
    parent_id.nil?
  end

  def progress_percentage
    return 0 if estimated_time.nil? || estimated_time.zero? || spent_time.nil?

    [(spent_time / estimated_time * 100).round(2), 100].min
  end

  def overdue?
    due_date.present? && due_date < Date.current && !resolved?
  end
end
