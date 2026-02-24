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
  before_save :normalize_status

  private

  def normalize_status
    self.status = status.downcase if status.present?
  end

  def due_date_after_start_date
    return if due_date.blank? || start_date.blank?

    return unless due_date < start_date

    errors.add(:due_date, 'must be greater than or equal to the start date')
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

  def unique_devices
    # 1. Check current task's device_config
    if device_config.present?
      return device_config.split(',').map(&:strip).reject(&:blank?)
    end

    # 2. Check parent task's device_config if it's a subtask
    if parent_id.present? && parent&.device_config.present?
      return parent.device_config.split(',').map(&:strip).reject(&:blank?)
    end

    # 3. Fallback to existing logic (from test results)
    devices = TestResult.active.joins(:test_case)
                        .where(test_cases: { task_id: id })
                        .pluck(:device).uniq.compact

    if devices.any?
      # Sort devices, but put "prod" or "production" at the end (case-insensitive)
      return devices.sort do |a, b|
        a_is_prod = a.to_s.downcase.match?(/^prod(uction)?$/)
        b_is_prod = b.to_s.downcase.match?(/^prod(uction)?$/)

        if a_is_prod && !b_is_prod
          1
        elsif !a_is_prod && b_is_prod
          -1
        else
          a.to_s.downcase <=> b.to_s.downcase
        end
      end
    end

    # 4. Ultimate fallback: empty
    []
  end

  def effective_device_config
    return device_config if device_config.present?
    return parent.device_config if parent_id.present? && parent&.device_config.present?
    nil
  end

  def total_test_cases_count
    # Sum direct test cases and all subtasks' test cases
    test_cases.active.count + subtasks.sum { |s| s.test_cases.active.count }
  end
end
