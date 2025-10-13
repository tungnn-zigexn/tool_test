class TestCase < ApplicationRecord
  belongs_to :task
  belongs_to :created_by, class_name: "User", foreign_key: "created_by_id"

  has_many :test_steps, dependent: :destroy
  has_many :test_results, dependent: :destroy

  enum test_type: {
    feature: "Feature",
    ui: "UI"
  }

  enum target: {
    pc_sp: "PC・SP",
    pc_sp_app: "PC・SP・APP",
    app: "APP",
    pc: "PC",
    sp: "SP"
  }

  validates :title, presence: true
  validates :task_id, presence: true
  validates :created_by_id, presence: true

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
    test_type&.titleize || "N/A"
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
