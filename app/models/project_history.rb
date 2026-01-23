class ProjectHistory < ApplicationRecord
  belongs_to :project
  belongs_to :user

  validates :project_id, presence: true
  validates :user_id, presence: true
  validates :action, presence: true

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :by_action, ->(action) { where(action: action) }
  scope :by_project, ->(project_id) { where(project_id: project_id) }

  # Instance Methods
  def action_description
    case action
    when 'create' then 'Created project'
    when 'update' then 'Updated project'
    when 'soft_delete' then 'Archived project'
    when 'restore' then 'Restored project'
    when 'destroy' then 'Permanently deleted project'
    else action.humanize
    end
  end

  def changes_summary
    return 'No changes recorded' if old_value.nil? && new_value.nil?

    begin
      old_data = old_value.present? ? JSON.parse(old_value) : {}
      new_data = new_value.present? ? JSON.parse(new_value) : {}

      changes = []

      # So sánh từng field
      (old_data.keys + new_data.keys).uniq.each do |key|
        next if key == 'updated_at' # Bỏ qua updated_at

        old_val = old_data[key]
        new_val = new_data[key]

        next unless old_val != new_val

        changes << if old_val.nil?
                     "Set #{key} to '#{new_val}'"
                   elsif new_val.nil?
                     "Removed #{key} (was '#{old_val}')"
                   else
                     "Changed #{key} from '#{old_val}' to '#{new_val}'"
                   end
      end

      changes.any? ? changes.join(', ') : 'No significant changes'
    rescue JSON::ParserError
      # Fallback nếu không parse được JSON
      if old_value.present? && new_value.present?
        "Changed from #{old_value} to #{new_value}"
      elsif new_value.present?
        "Set to #{new_value}"
      else
        "Removed #{old_value}"
      end
    end
  end

  def field_changes
    return {} if old_value.nil? || new_value.nil?

    begin
      old_data = JSON.parse(old_value)
      new_data = JSON.parse(new_value)

      changes = {}
      (old_data.keys + new_data.keys).uniq.each do |key|
        next if key == 'updated_at'

        old_val = old_data[key]
        new_val = new_data[key]

        changes[key] = { old: old_val, new: new_val } if old_val != new_val
      end

      changes
    rescue JSON::ParserError
      {}
    end
  end
end
