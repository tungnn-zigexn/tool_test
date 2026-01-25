module Loggable
  extend ActiveSupport::Concern

  included do
    after_create :log_create
    after_update :log_update

    # Check if the model has soft delete/restore (assuming SoftDeletable concern)
    if method_defined?(:soft_delete)
      # We might need to wrap or use a different hook if soft_delete is called via update
    end
  end

  private

  def log_create
    return if Current.user.nil?

    ActivityLog.create(
      user: Current.user,
      trackable: self,
      action_type: 'create',
      metadata: format_changes(saved_changes.except('created_at', 'updated_at', 'deleted_at'))
    )
  end

  def log_update
    return if Current.user.nil?

    changes = saved_changes.except('updated_at')
    return if changes.empty?

    action = 'update'
    if changes['deleted_at']
      action = changes['deleted_at'][1].present? ? 'delete' : 'restore'
    end

    ActivityLog.create(
      user: Current.user,
      trackable: self,
      action_type: action,
      metadata: format_changes(changes)
    )
  end

  def format_changes(changes)
    formatted = {}
    changes.each do |field, values|
      # Find if this field is a foreign key for any belongs_to association
      reflection = self.class.reflections.values.find { |r| r.belongs_to? && r.foreign_key.to_s == field.to_s }

      if reflection
        klass = begin
          reflection.klass
        rescue StandardError
          nil
        end
        if klass
          resolver = lambda { |id|
            return 'N/A' if id.blank?

            record = klass.unscoped.find_by(id: id)
            return id.to_s unless record

            record.try(:name) || record.try(:title) || record.try(:full_name) || id.to_s
          }

          display_name = reflection.name.to_s.humanize
          formatted[display_name] = [resolver.call(values[0]), resolver.call(values[1])]
          next
        end
      end
      formatted[field] = values
    end
    formatted
  end
end
