module ApplicationHelper
  # Render a toast notification
  # Usage: render_toast("Message", type: "success")
  def render_toast(message, type: 'info')
    render partial: 'shared/toast', locals: { message: message, type: type }
  end

  def status_badge_color(status)
    case status.to_s.downcase
    when 'new', 'open'
      'bg-primary text-white'
    when 'in progress', 'working'
      'bg-info text-dark'
    when 'resolved', 'fixed'
      'bg-success text-white'
    when 'closed', 'done'
      'bg-secondary text-white'
    when 'feedback', 'reopen', 'reopened'
      'bg-danger text-white'
    when 'testing', 'verify'
      'bg-warning text-dark'
    else
      'bg-light text-dark border'
    end
  end
end
