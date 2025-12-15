class TestCase < ApplicationRecord
  belongs_to :task
  belongs_to :created_by, class_name: "User", foreign_key: "created_by_id", optional: true

  has_many :test_steps, foreign_key: "case_id", dependent: :destroy, inverse_of: :test_case
  has_many :test_results, foreign_key: "case_id", dependent: :destroy

  # Nested attributes for creating test steps
  accepts_nested_attributes_for :test_steps, allow_destroy: true

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

  # Device results helpers - Query from test_results table
  def parsed_device_results
    test_results.active.map do |result|
      {
        device: result.device || "Unknown",
        status: result.status || "unknown"
      }
    end
  end

  def has_device_results?
    test_results.active.any?
  end
end
