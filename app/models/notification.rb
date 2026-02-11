# frozen_string_literal: true

class Notification < ApplicationRecord
  CATEGORIES = %w[cronjob system info warning].freeze

  has_many :notification_reads, dependent: :destroy

  validates :category, inclusion: { in: CATEGORIES }
  validates :title, presence: true

  scope :recent, -> { order(created_at: :desc) }

  # Notifications not yet read by this user
  scope :unread_for, ->(user) {
    where.not(id: NotificationRead.where(user: user).select(:notification_id))
  }
end
