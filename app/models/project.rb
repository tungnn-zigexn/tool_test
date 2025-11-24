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
  def task_count
    tasks.root_tasks.active.count
  end

  def completed_task_count
    tasks.root_tasks.where(status: "resolved").count
  end
end
