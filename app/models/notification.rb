# frozen_string_literal: true

class Notification < ApplicationRecord
  CATEGORIES = %w[cronjob system info warning].freeze

  has_many :notification_reads, dependent: :destroy

  validates :category, inclusion: { in: CATEGORIES }
  validates :title, presence: true

  scope :recent, -> { order(created_at: :desc) }

  after_create_commit :broadcast_new_notification

  # Notifications not yet read by this user
  scope :unread_for, ->(user) {
    where.not(id: NotificationRead.where(user: user).select(:notification_id))
  }

  def broadcast_payload
    {
      event: "notification",
      data: {
        id: id,
        title: title,
        message: message.to_s.truncate(80),
        link: link,
        category: category,
        created_at: created_at.iso8601
      }
    }
  end

  private

  def broadcast_new_notification
    if category == "cronjob"
      User.admin.find_each { |u| UserChannel.broadcast_to(u, broadcast_payload) }
    else
      ActionCable.server.broadcast("notifications", broadcast_payload)
    end
  end
end
