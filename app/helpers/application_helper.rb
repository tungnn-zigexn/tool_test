module ApplicationHelper
  # Render a toast notification
  # Usage: render_toast("Message", type: "success")
  def render_toast(message, type: 'info')
    render partial: 'shared/toast', locals: { message: message, type: type }
  end
end
