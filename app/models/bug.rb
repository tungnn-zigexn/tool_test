class Bug < ApplicationRecord
  belongs_to :task
  belongs_to :dev, class_name: "User", foreign_key: "dev_id", optional: true
  belongs_to :tester, class_name: "User", foreign_key: "tester_id", optional: true
  belongs_to :test_result, optional: true

  has_many :bug_evidences, dependent: :destroy
  has_many :bug_comments, dependent: :nullify

  enum category: {
    stg_vn: "STG Bugs (VN)",
    stg_jp: "STG Bugs (JP)",
    new_requirement: "New Requirement",
    prod: "Prod Bugs"
  }

  enum priority: { high: "high", normal: "normal", low: "low" }
  enum status: { new: "new", fixing: "fixing", testing: "testing", done: "done", pending: "pending" }

  # Application type enum (từ sheet Bug)
  enum application: {
    sp_pc: "SP + PC",
    app: "APP",
    sp: "SP",
    pc: "PC",
    all: "SP + PC + APP"
  }

  validates :title, presence: true
  validates :task_id, presence: true
  validates :category, presence: true
  validates :priority, presence: true
  validates :status, presence: true

  scope :active, -> { where(deleted_at: nil) }
  scope :deleted, -> { where.not(deleted_at: nil) }
  scope :open, -> { where(status: [ "new", "fixing", "testing", "pending" ]) }
  scope :closed, -> { where(status: "done") }
  scope :by_category, ->(category) { where(category: category) }
  scope :by_priority, ->(priority) { where(priority: priority) }
  scope :by_application, ->(app) { where(application: app) }

  def soft_delete!
    update!(deleted_at: Time.current)
  end

  def active?
    deleted_at.nil?
  end

  def open?
    [ "new", "fixing", "testing", "pending" ].include?(status)
  end

  def closed?
    status == "done"
  end

  def evidence_count
    bug_evidences.count
  end

  def from_test_result?
    test_result_id.present?
  end

  def priority_color
    case priority
    when "high" then "danger"
    when "normal" then "warning"
    when "low" then "info"
    else "secondary"
    end
  end

  def status_color
    case status
    when "new" then "primary"
    when "fixing" then "warning"
    when "testing" then "info"
    when "done" then "success"
    when "pending" then "secondary"
    else "secondary"
    end
  end

  def category_display
    case category
    when "stg_vn" then "STG Bugs (VN)"
    when "stg_jp" then "STG Bugs (JP)"
    when "new_requirement" then "New Requirement"
    when "prod" then "Prod Bugs"
    else category.humanize
    end
  end

  def application_display
    case application
    when "sp_pc" then "SP + PC"
    when "app" then "APP"
    when "sp" then "SP"
    when "pc" then "PC"
    when "all" then "SP + PC + APP"
    else application&.humanize || "N/A"
    end
  end

  # Export to sheet format (giống Bug sheet trong ảnh)
  def to_sheet_row
    {
      no: id,
      content: content,
      application: application_display,
      category: category_display,
      priority: priority.titleize,
      dev: dev&.name,
      tester: tester&.name,
      status: status.titleize,
      image_video: image_video_url,
      note: notes,
      clock: clock,
      bugs_count: task.bugs.by_category(category).count
    }
  end
end
