class ActivityLog < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :trackable, polymorphic: true

  default_scope { order(created_at: :desc) }

  def action_display
    case action_type
    when 'create' then 'đã tạo'
    when 'update' then 'đã cập nhật'
    when 'delete' then 'đã xóa'
    when 'restore' then 'đã khôi phục'
    when 'import' then 'đã đồng bộ'
    else action_type
    end
  end
end
