class Project < ApplicationRecord
  has_many :tasks, dependent: :destroy

  validates :name, presence: true

  scope :active, -> { where(deleted_at: nil) }
  scope :deleted, -> { where.not(deleted_at: nil) }

  def soft_delete!
    update!(deleted_at: Time.current)
  end

  def active?
    deleted_at.nil?
  end

  # Đếm tasks (không tính subtask)
  # Đếm tasks (không tính subtask, bao gồm cả orphaned)
  def task_count
    # Simple count of roots + check for orphans would be expensive in Ruby loop.
    # SQL way: tasks where parent_id is NULL OR parent_id NOT IN (select id from tasks where project_id = project.id)
    tasks.active.where("parent_id IS NULL OR parent_id NOT IN (SELECT id FROM tasks WHERE project_id = ?)", id).count
  end

  def completed_task_count
    tasks.root_tasks.where(status: "resolved").count
  end
end
