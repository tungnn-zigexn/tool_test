class TestCase < ApplicationRecord
  include SoftDeletable
  include Loggable

  belongs_to :task
  belongs_to :created_by, class_name: 'User', foreign_key: 'created_by_id', optional: true

  has_many :test_steps, foreign_key: 'case_id', dependent: :delete_all, inverse_of: :test_case
  has_many :test_results, foreign_key: 'case_id', dependent: :delete_all

  # Nested attributes for creating test steps - reject blank steps
  accepts_nested_attributes_for :test_steps, allow_destroy: true, reject_if: lambda { |attrs|
    # Reject if step_number is blank or description is blank and no contents
    attrs[:step_number].blank? && attrs[:description].blank?
  }

  validates :title, presence: true
  validates :task_id, presence: true

  scope :by_type, ->(type) { where(test_type: type) }
  scope :by_target, ->(target) { where(target: target) }
  scope :ordered, -> { order(id: :asc) }

  def step_count
    test_steps.count
  end

  # Helper cho display
  def test_type_display
    case test_type
    when 'feature' then 'Feature'
    when 'ui' then 'UI'
    else test_type&.titleize || 'N/A'
    end
  end

  def target_display
    case target
    when 'pc_sp' then 'PC・SP'
    when 'pc_sp_app' then 'PC・SP・APP'
    when 'app' then 'APP'
    when 'pc' then 'PC'
    when 'sp' then 'SP'
    else target&.upcase || 'N/A'
    end
  end

  # Device results helpers - Query from test_results table
  def parsed_device_results
    test_results.active.map do |result|
      {
        device: result.device || 'Unknown',
        status: result.status || 'unknown'
      }
    end
  end

  def device_results?
    test_results.active.any?
  end

  def latest_status_for(device_or_category)
    results = test_results.active.recent
    # First try exact match
    match = results.find { |r| r.device == device_or_category }
    # Then try category match
    match ||= results.find { |r| device_match?(r.device, device_or_category) }
    match&.status || 'not_run'
  end

  private

  def device_match?(device_name, category)
    return false if device_name.blank?

    name = device_name.downcase

    case category.to_s.downcase
    when 'pc'
      name.match?(/chrome|firefox|safari|edge|prod|stg|pc/) && !name.match?(/android|ios|iphone|ipad/)
    when 'sp'
      name.match?(/android|ios|iphone|ipad|testflight|deploy.*gate|sp/)
    when 'app'
      name.match?(/app/) || (name.match?(/android|ios|iphone|ipad/) && name.match?(/2\.\d\.\d/)) # Example version match
    else
      name == category.to_s.downcase
    end
  end
end
