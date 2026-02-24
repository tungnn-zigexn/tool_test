class TestCase < ApplicationRecord
  include SoftDeletable
  include Loggable

  belongs_to :task
  belongs_to :created_by, class_name: 'User', foreign_key: 'created_by_id', optional: true

  has_one :test_step, foreign_key: 'case_id', dependent: :destroy, inverse_of: :test_case
  has_many :test_steps, foreign_key: 'case_id', dependent: :delete_all, inverse_of: :test_case # Alias for backward compatibility if needed in old views
  has_many :test_results, foreign_key: 'case_id', dependent: :delete_all

  # Nested attributes for creating single test step
  accepts_nested_attributes_for :test_step, allow_destroy: true

  validates :title, presence: true
  validates :task_id, presence: true

  before_validation :strip_title

  scope :by_type, ->(type) { where(test_type: type) }
  scope :by_target, ->(target) { where(target: target) }
  scope :ordered, -> { order(Arel.sql("COALESCE(position, id) ASC, id ASC")) }

  before_create :assign_default_position

  # Insert TC at a specific position, shift subsequent TCs down
  def self.insert_at_position!(task, target_position)
    task.test_cases.active.where("position >= ?", target_position).update_all("position = position + 1")
  end

  def step_count
    test_steps.count
  end

  # Helper cho display
  def test_type_display
    case test_type
    when 'feature' then 'Feature'
    when 'ui' then 'UI'
    when 'data' then 'Data'
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

  def latest_status_info_for(device_or_category)
    status = latest_status_for(device_or_category)
    bg_class = case status
               when 'pass' then 'bg-success bg-opacity-10'
               when 'fail' then 'bg-danger bg-opacity-10'
               when 'blocked' then 'bg-warning bg-opacity-10'
               else ''
               end
    { status: status, bg_class: bg_class }
  end

  after_save :update_task_counter
  after_destroy :update_task_counter
  after_update :sync_grouped_titles, if: :saved_change_to_title?

  private

  def sync_grouped_titles
    old_title, new_title = saved_changes[:title]
    return if old_title.blank? || new_title.blank?

    # Find siblings with the exact same old title in the same task
    siblings = task.test_cases.active.where(title: old_title).where.not(id: id)
    sibling_ids = siblings.pluck(:id)
    
    return if sibling_ids.empty?

    # Update all siblings at once (avoids callback recursion)
    task.test_cases.where(id: sibling_ids).update_all(title: new_title, updated_at: Time.current)

    # Broadcast updates to the UI for each sibling
    sibling_ids.each do |s_id|
      # Broadcast to the task's stream, targeting each specific title cell
      broadcast_update_to task, 
                          target: "test-case-#{s_id}-title", 
                          html: new_title
    end
  end

  def strip_title
    if title.present?
      self.title = CGI.unescapeHTML(title.to_s).strip
    end
  end

  def assign_default_position
    return if position.present?
    max_pos = task.test_cases.maximum(:position) || 0
    self.position = max_pos + 1
  end

  def update_task_counter
    # Update current task
    task.update_columns(number_of_test_cases: task.test_cases.active.count) if task
    
    # If task_id changed, update the previous task as well
    if saved_change_to_task_id?
      old_task_id = saved_changes[:task_id].first
      if old_task_id
        old_task = Task.find_by(id: old_task_id)
        old_task.update_columns(number_of_test_cases: old_task.test_cases.active.count) if old_task
      end
    end
  end

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
