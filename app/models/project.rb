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

  def task_count
    tasks.active.count
  end

  def completed_task_count
    tasks.where(status: "resolved").count
  end
end
