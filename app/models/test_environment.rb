class TestEnvironment < ApplicationRecord
  has_many :test_results, foreign_key: 'environment_id', dependent: :nullify

  validates :name, presence: true

  scope :active, -> { where(deleted_at: nil) }
  scope :deleted, -> { where.not(deleted_at: nil) }

  def soft_delete!
    update!(deleted_at: Time.current)
  end

  def active?
    deleted_at.nil?
  end

  def full_name
    parts = [name]
    parts << version if version.present?
    parts << os if os.present?
    parts.join(' - ')
  end

  def result_count
    test_results.count
  end

  def pass_rate
    total = result_count
    return 0 if total.zero?

    passed = test_results.where(status: 'pass').count
    (passed.to_f / total * 100).round(2)
  end
end
