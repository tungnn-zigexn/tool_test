class TestCase < ApplicationRecord
  belongs_to :task
  belongs_to :created_by, class_name: "User", foreign_key: "created_by_id", optional: true

  has_many :test_steps, foreign_key: "case_id", dependent: :destroy
  has_many :test_results, foreign_key: "case_id", dependent: :destroy


  validates :title, presence: true
  validates :task_id, presence: true

  scope :active, -> { where(deleted_at: nil) }
  scope :deleted, -> { where.not(deleted_at: nil) }
  scope :by_type, ->(type) { where(test_type: type) }
  scope :by_target, ->(target) { where(target: target) }

  def soft_delete!
    update!(deleted_at: Time.current)
  end

  def active?
    deleted_at.nil?
  end

  def step_count
    test_steps.count
  end

  def latest_test_result
    test_results.order(executed_at: :desc).first
  end

  def pass_rate
    total_runs = test_results.count
    return 0 if total_runs.zero?

    passed_runs = test_results.where(status: "pass").count
    (passed_runs.to_f / total_runs * 100).round(2)
  end

  # Helper cho display
  def test_type_display
    case test_type
    when "feature" then "Feature"
    when "ui" then "UI"
    else test_type&.titleize || "N/A"
    end
  end

  def target_display
    case target
    when "pc_sp" then "PC・SP"
    when "pc_sp_app" then "PC・SP・APP"
    when "app" then "APP"
    when "pc" then "PC"
    when "sp" then "SP"
    else target&.upcase || "N/A"
    end
  end

  # Device results helpers
  def parsed_device_results
    return [] if device_results.blank?

    begin
      JSON.parse(device_results, symbolize_names: true)
    rescue JSON::ParserError
      []
    end
  end

  def has_device_results?
    parsed_device_results.any?
  end

  def device_status_counts
    results = parsed_device_results
    return {} if results.empty?

    {
      pass: results.count { |r| r[:status] == "pass" },
      failed: results.count { |r| r[:status] == "failed" },
      not_run: results.count { |r| r[:status] == "not_run" },
      blocked: results.count { |r| r[:status] == "blocked" },
      unknown: results.count { |r| r[:status] == "unknown" }
    }
  end

  def overall_status
    return "not_tested" unless has_device_results?

    counts = device_status_counts
    return "failed" if counts[:failed] > 0
    return "blocked" if counts[:blocked] > 0
    return "not_run" if counts[:not_run] > 0 && counts[:pass] == 0
    return "pass" if counts[:pass] > 0 && counts[:failed] == 0
    "unknown"
  end

  # Export to sheet format
  def to_sheet_row
    {
      id: id,
      test_type: test_type_display,
      function: function,
      test_steps: test_steps.ordered.map(&:summary).join("\n"),
      expected_result: test_steps.ordered.map(&:expected_summary).join("\n"),
      target: target_display,
      acceptance_criteria: acceptance_criteria_url,
      user_story: user_story_url
    }
  end
end
