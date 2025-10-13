class TaskHistory < ApplicationRecord
  belongs_to :task
  belongs_to :user

  enum action: { create: 'create', update: 'update', delete: 'delete', status_change: 'status_change' }

  validates :task_id, presence: true
  validates :user_id, presence: true
  validates :action, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :by_action, ->(action) { where(action: action) }

  def action_description
    case action
    when 'create' then 'Created task'
    when 'update' then 'Updated task'
    when 'delete' then 'Deleted task'
    when 'status_change' then 'Changed status'
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




