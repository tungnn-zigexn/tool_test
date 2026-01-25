class TestRun < ApplicationRecord
  belongs_to :task
  belongs_to :executed_by, class_name: 'User', foreign_key: 'executed_by_id', optional: true

  has_many :test_results, foreign_key: 'run_id', dependent: :delete_all

  validates :name, presence: true
  validates :task_id, presence: true
  validates :status, presence: true

  scope :active, -> { where(deleted_at: nil) }
  scope :deleted, -> { where.not(deleted_at: nil) }
  scope :recent, -> { order(executed_at: :desc) }
  scope :by_status, ->(status) { where(status: status) }
  scope :in_progress, -> { where(status: %w[pending running]) }
  scope :finished, -> { where(status: %w[completed aborted]) }

  def soft_delete!
    update!(deleted_at: Time.current)
  end

  def active?
    deleted_at.nil?
  end

  def in_progress?
    %w[pending running].include?(status)
  end

  def finished?
    %w[completed aborted].include?(status)
  end

  def result_count
    test_results.count
  end

  def pass_count
    test_results.where(status: 'pass').count
  end

  def fail_count
    test_results.where(status: 'fail').count
  end

  def not_run_count
    test_results.where(status: 'not run').count
  end

  def pass_rate
    total = result_count
    return 0 if total.zero?

    (pass_count.to_f / total * 100).round(2)
  end

  def status_summary
    "#{pass_count} pass, #{fail_count} fail, #{not_run_count} not run"
  end

  # Tính thời gian thực thi
  def execution_duration
    return nil if started_at.nil? || completed_at.nil?

    completed_at - started_at
  end

  def execution_duration_formatted
    return 'N/A' if execution_duration.nil?

    seconds = execution_duration.to_i
    hours = seconds / 3600
    minutes = (seconds % 3600) / 60
    secs = seconds % 60

    if hours.positive?
      "#{hours}h #{minutes}m #{secs}s"
    elsif minutes.positive?
      "#{minutes}m #{secs}s"
    else
      "#{secs}s"
    end
  end

  # Tự động cập nhật trạng thái
  def start!
    update!(status: 'running', started_at: Time.current)
  end

  def complete!
    update!(status: 'completed', completed_at: Time.current)
  end

  def abort!
    update!(status: 'aborted', completed_at: Time.current)
  end

  def status_color
    case status
    when 'running' then 'info'
    when 'completed' then 'success'
    when 'aborted' then 'danger'
    else 'secondary'
    end
  end
end
