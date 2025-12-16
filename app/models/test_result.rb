class TestResult < ApplicationRecord
  belongs_to :test_run, foreign_key: 'run_id', optional: true
  belongs_to :test_case, foreign_key: 'case_id'
  belongs_to :executed_by, class_name: 'User', foreign_key: 'executed_by_id', optional: true
  belongs_to :test_environment, foreign_key: 'environment_id', optional: true
  has_one :bug, dependent: :nullify

  validates :case_id, presence: true
  validates :status, presence: true

  scope :active, -> { where(deleted_at: nil) }
  scope :deleted, -> { where.not(deleted_at: nil) }
  scope :recent, -> { order(executed_at: :desc) }
  scope :by_status, ->(status) { where(status: status) }
  scope :failed_with_bugs, -> { where(status: 'fail').joins(:bug) }

  before_save :calculate_execution_time, if: :should_calculate_execution_time?

  def soft_delete!
    update!(deleted_at: Time.current)
  end

  def active?
    deleted_at.nil?
  end

  private

  def should_calculate_execution_time?
    # Only calculate if both columns exist and have values
    respond_to?(:ended_at) && respond_to?(:started_at) &&
      ended_at.present? && started_at.present?
  end

  def calculate_execution_time
    if respond_to?(:started_at) && respond_to?(:ended_at) &&
       started_at.present? && ended_at.present?
      self.execution_time = (ended_at - started_at).to_i
    end
  end
end
