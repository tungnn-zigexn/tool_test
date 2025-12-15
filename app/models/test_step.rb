class TestStep < ApplicationRecord
  belongs_to :test_case, foreign_key: "case_id", inverse_of: :test_steps
  has_many :test_step_contents, foreign_key: "step_id", dependent: :destroy, inverse_of: :test_step

  # Nested attributes for creating step contents
  accepts_nested_attributes_for :test_step_contents, allow_destroy: true

  validates :step_number, presence: true, numericality: { greater_than: 0 }

  scope :ordered, -> { order(:step_number) }

  # Thêm các scope để lấy contents theo category
  def action_contents
    test_step_contents.where(content_category: "action").order(:display_order)
  end

  def expected_contents
    test_step_contents.where(content_category: "expectation").order(:display_order)
  end

  def content_count
    test_step_contents.count
  end

  def has_actions?
    action_contents.exists?
  end

  def has_expectations?
    expected_contents.exists?
  end

  # Tạo summary của step
  def action_summary
    actions = action_contents.pluck(:content_value).join(", ")
    actions.presence || "No action defined"
  end

  def expected_summary
    expectations = expected_contents.pluck(:content_value).join(", ")
    expectations.presence || "No expectation defined"
  end

  # Full summary
  def summary
    "Step #{step_number}: #{action_summary} → Expected: #{expected_summary}"
  end
end
