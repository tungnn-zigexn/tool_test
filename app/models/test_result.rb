class TestResult < ApplicationRecord
  belongs_to :test_run, foreign_key: "run_id"
  belongs_to :test_case, foreign_key: "case_id"
  belongs_to :executed_by, class_name: "User", foreign_key: "executed_by_id", optional: true
  belongs_to :test_environment, foreign_key: "environment_id", optional: true
  has_one :bug, dependent: :nullify

  enum status: { pass: "pass", fail: "fail", not_run: "not run", blocked: "blocked" }

  validates :run_id, presence: true
  validates :case_id, presence: true
  validates :status, presence: true

  scope :active, -> { where(deleted_at: nil) }
  scope :deleted, -> { where.not(deleted_at: nil) }
  scope :recent, -> { order(executed_at: :desc) }
  scope :by_status, ->(status) { where(status: status) }
  scope :failed_with_bugs, -> { where(status: "fail").joins(:bug) }

  before_save :calculate_execution_time, if: :will_save_change_to_ended_at?

  def soft_delete!
    update!(deleted_at: Time.current)
  end

  def active?
    deleted_at.nil?
  end

  def passed?
    status == "pass"
  end

  def failed?
    status == "fail"
  end

  def not_run?
    status == "not run"
  end

  def blocked?
    status == "blocked"
  end

  def has_bug?
    bug.present?
  end

  def environment_name
    test_environment&.name || "Unknown"
  end

  # Tính thời gian thực thi (giây)
  def execution_duration
    return nil if started_at.nil? || ended_at.nil?
    (ended_at - started_at).to_i
  end

  # Format thời gian thực thi
  def execution_duration_formatted
    return "N/A" if execution_duration.nil?

    seconds = execution_duration
    if seconds < 60
      "#{seconds}s"
    elsif seconds < 3600
      minutes = seconds / 60
      secs = seconds % 60
      "#{minutes}m #{secs}s"
    else
      hours = seconds / 3600
      minutes = (seconds % 3600) / 60
      "#{hours}h #{minutes}m"
    end
  end

  # Status color
  def status_color
    case status
    when "pass" then "success"
    when "fail" then "danger"
    when "not run" then "secondary"
    else "secondary"
    end
  end

  # Status icon
  def status_icon
    case status
    when "pass" then "✅"
    when "fail" then "❌"
    when "not run" then "⏸️"
    when "blocked" then "🚫"
    else "❓"
    end
  end

  # Summary cho report
  def summary
    parts = [
      "Case: #{test_case.title}",
      "Status: #{status.upcase}",
      "Environment: #{environment_name}"
    ]
    parts << "Duration: #{execution_duration_formatted}" if execution_duration
    parts << "Bug: ##{bug.id}" if has_bug?
    parts.join(" | ")
  end

  # Export to sheet format (theo từng environment)
  def to_sheet_cell
    case status
    when "pass" then "Pass"
    when "fail" then "Fail"
    when "blocked" then "Blocked"
    else "Not Run"
    end
  end

  private

  def calculate_execution_time
    if started_at.present? && ended_at.present?
      self.execution_time = (ended_at - started_at).to_i
    end
  end
end
