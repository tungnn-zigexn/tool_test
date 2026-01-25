class Project < ApplicationRecord
  include SoftDeletable

  has_many :tasks, dependent: :destroy

  # Override soft_delete! to cascade to tasks
  def soft_delete!
    transaction do
      super
      tasks.active.update_all(deleted_at: deleted_at)
    end
  end

  # Override restore! to cascade to tasks
  def restore!
    transaction do
      tasks.where(deleted_at: deleted_at).update_all(deleted_at: nil)
      super
    end
  end

  validates :name, presence: true, length: { maximum: 50 }, uniqueness: { case_sensitive: false }

  # Đếm tasks (không tính subtask)
  def task_count
    root_tasks.count
  end

  def completed_task_count
    root_tasks.where(status: %w[Closed resolved]).count
  end

  def root_tasks
    # A task is a root if it has no parent or its parent doesn't exist in the same project
    tasks.active.where('parent_id IS NULL OR parent_id NOT IN (SELECT id FROM tasks WHERE project_id = ?)', id)
  end
end
