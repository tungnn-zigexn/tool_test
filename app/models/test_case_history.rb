class TestCaseHistory < ApplicationRecord
  belongs_to :test_case
  belongs_to :user

  validates :test_case_id, presence: true
  validates :user_id, presence: true
  validates :action, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :by_action, ->(action) { where(action: action) }

  def action_description
    case action
    when 'create' then 'Created test case'
    when 'update' then 'Updated test case'
    when 'delete' then 'Deleted test case'
    else action.humanize
    end
  end

  def changes_summary
    return 'No changes recorded' if old_value.nil? && new_value.nil?

    if old_value.present? && new_value.present?
      "Changed from #{old_value} to #{new_value}"
    elsif new_value.present?
      "Set to #{new_value}"
    else
      "Removed #{old_value}"
    end
  end
end
