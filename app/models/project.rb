class Project < ApplicationRecord
  include SoftDeletable
  has_many :tasks, dependent: :destroy

  validates :name, presence: true

  # Đếm tasks (không tính subtask)
  def task_count
    root_tasks.count
  end

  def completed_task_count
    root_tasks.where(status: ['Closed', 'resolved']).count
  end

  def root_tasks
    # A task is a root if it has no parent or its parent doesn't exist in the same project
    tasks.active.where('parent_id IS NULL OR parent_id NOT IN (SELECT id FROM tasks WHERE project_id = ?)', id)
  end

  private
end
