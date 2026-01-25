class Task < ApplicationRecord
  include SoftDeletable
  include Loggable

  belongs_to :project
  belongs_to :assignee, class_name: 'User', foreign_key: 'assignee_id', optional: true
  belongs_to :parent, class_name: 'Task', foreign_key: 'parent_id', optional: true

  has_many :subtasks, class_name: 'Task', foreign_key: 'parent_id', dependent: :destroy
  has_many :test_cases, dependent: :destroy
  has_many :test_runs, dependent: :destroy
  has_many :bugs, dependent: :destroy

  validates :title, presence: true
  validates :estimated_time, :spent_time, numericality: { greater_than_or_equal_to: 0, allow_nil: true }
  validates :percent_done, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100, allow_nil: true }
  validate :due_date_after_start_date

  private

  def due_date_after_start_date
    return if due_date.blank? || start_date.blank?

    return unless due_date < start_date

    errors.add(:due_date, 'phải lớn hơn hoặc bằng ngày bắt đầu')
  end

  public

  scope :root_tasks, lambda {
    where(parent_id: nil, redmine_id: nil)
      .or(where.not(parent_id: nil).where.not(redmine_id: nil))
  }

  def subtask?
    !root_task?
  end

  def root_task?
    (parent_id.nil? && redmine_id.nil?) || (parent_id.present? && redmine_id.present?)
  end

  def progress_percentage
    return 0 if estimated_time.nil? || estimated_time.zero? || spent_time.nil?

    [(spent_time / estimated_time * 100).round(2), 100].min
  end

  def overdue?
    due_date.present? && due_date < Date.current && !resolved?
  end
end
