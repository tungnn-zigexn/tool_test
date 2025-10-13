class BugEvidence < ApplicationRecord
  belongs_to :bug

  enum content_type: { text: 'text', link: 'link', image: 'image', file: 'file' }

  validates :bug_id, presence: true
  validates :content_type, presence: true
  validates :content_value, presence: true

  scope :by_type, ->(type) { where(content_type: type) }
end




