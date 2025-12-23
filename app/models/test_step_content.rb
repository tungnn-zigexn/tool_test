class TestStepContent < ApplicationRecord
  belongs_to :test_step, foreign_key: 'step_id', inverse_of: :test_step_contents

  validates :content_type, presence: true
  validates :content_value, presence: true
  validates :content_category, presence: true

  scope :actions, -> { where(content_category: 'action') }
  scope :expectations, -> { where(content_category: 'expectation') }
  scope :by_type, ->(type) { where(content_type: type) }
  scope :ordered, -> { order(:display_order) }

  # Helper methods
  def action?
    content_category == 'action'
  end

  def expectation?
    content_category == 'expectation'
  end

  def text?
    content_type == 'text'
  end

  def link?
    content_type == 'link'
  end

  def image?
    content_type == 'image'
  end

  # Display helpers
  def category_label
    case content_category
    when 'action' then 'Action'
    when 'expectation' then 'Expected Result'
    else content_category.humanize
    end
  end

  def type_icon
    case content_type
    when 'text' then '📝'
    when 'link' then '🔗'
    when 'image' then '🖼️'
    else '📄'
    end
  end
end
