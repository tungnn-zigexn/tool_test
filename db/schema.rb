# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_02_11_140000) do
  create_table "activity_logs", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "trackable_type", null: false
    t.integer "trackable_id", null: false
    t.string "action_type"
    t.json "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["trackable_type", "trackable_id"], name: "index_activity_logs_on_trackable"
    t.index ["user_id"], name: "index_activity_logs_on_user_id"
  end

  create_table "app_configurations", force: :cascade do |t|
    t.boolean "daily_import_enabled", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "bug_comments", force: :cascade do |t|
    t.integer "bug_id", null: false
    t.integer "user_id", null: false
    t.text "content", null: false
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bug_id"], name: "index_bug_comments_on_bug_id"
    t.index ["deleted_at"], name: "index_bug_comments_on_deleted_at"
    t.index ["user_id"], name: "index_bug_comments_on_user_id"
  end

  create_table "bug_evidences", force: :cascade do |t|
    t.integer "bug_id", null: false
    t.string "content_type", null: false
    t.text "content_value", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bug_id"], name: "index_bug_evidences_on_bug_id"
    t.index ["content_type"], name: "index_bug_evidences_on_content_type"
  end

  create_table "bugs", force: :cascade do |t|
    t.integer "task_id", null: false
    t.integer "dev_id"
    t.integer "tester_id"
    t.string "title", null: false
    t.text "description"
    t.string "category", null: false
    t.string "priority", null: false
    t.string "status", default: "new", null: false
    t.text "content"
    t.string "application"
    t.string "image_video_url"
    t.text "notes"
    t.string "clock"
    t.integer "test_result_id"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "dev_name_raw"
    t.string "tester_name_raw"
    t.index ["application"], name: "index_bugs_on_application"
    t.index ["category"], name: "index_bugs_on_category"
    t.index ["deleted_at"], name: "index_bugs_on_deleted_at"
    t.index ["dev_id"], name: "index_bugs_on_dev_id"
    t.index ["priority"], name: "index_bugs_on_priority"
    t.index ["status"], name: "index_bugs_on_status"
    t.index ["task_id"], name: "index_bugs_on_task_id"
    t.index ["test_result_id"], name: "index_bugs_on_test_result_id"
    t.index ["tester_id"], name: "index_bugs_on_tester_id"
  end

  create_table "daily_import_runs", force: :cascade do |t|
    t.integer "project_id", null: false
    t.string "status", default: "pending", null: false
    t.datetime "started_at"
    t.datetime "finished_at"
    t.integer "imported_count", default: 0
    t.integer "skipped_count", default: 0
    t.text "error_message"
    t.text "log_output"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id", "started_at"], name: "index_daily_import_runs_on_project_id_and_started_at", order: { started_at: :desc }
    t.index ["project_id"], name: "index_daily_import_runs_on_project_id"
  end

  create_table "notification_reads", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "notification_id", null: false
    t.datetime "read_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["notification_id"], name: "index_notification_reads_on_notification_id"
    t.index ["user_id", "notification_id"], name: "index_notification_reads_on_user_id_and_notification_id", unique: true
    t.index ["user_id"], name: "index_notification_reads_on_user_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.string "category", default: "info", null: false
    t.string "title", null: false
    t.text "message"
    t.string "link"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category"], name: "index_notifications_on_category"
    t.index ["created_at"], name: "index_notifications_on_created_at", order: :desc
  end

  create_table "projects", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "redmine_project_id"
    t.boolean "daily_import_enabled", default: false, null: false
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.string "concurrency_key", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.text "error"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "queue_name", null: false
    t.string "class_name", null: false
    t.text "arguments"
    t.integer "priority", default: 0, null: false
    t.string "active_job_id"
    t.datetime "scheduled_at"
    t.datetime "finished_at"
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.string "queue_name", null: false
    t.datetime "created_at", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.bigint "supervisor_id"
    t.integer "pid", null: false
    t.string "hostname"
    t.text "metadata"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "task_key", null: false
    t.datetime "run_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.string "key", null: false
    t.string "schedule", null: false
    t.string "command", limit: 2048
    t.string "class_name"
    t.text "arguments"
    t.string "queue_name"
    t.integer "priority", default: 0
    t.boolean "static", default: true, null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "scheduled_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.string "key", null: false
    t.integer "value", default: 1, null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "tasks", force: :cascade do |t|
    t.integer "redmine_id"
    t.integer "project_id", null: false
    t.integer "assignee_id"
    t.integer "parent_id"
    t.integer "subtask_id"
    t.string "title", null: false
    t.text "description"
    t.string "status"
    t.decimal "estimated_time", precision: 5, scale: 2
    t.decimal "spent_time", precision: 5, scale: 2
    t.integer "percent_done"
    t.date "start_date"
    t.date "due_date"
    t.string "testcase_link"
    t.string "bug_link"
    t.string "created_by_name"
    t.string "reviewed_by_name"
    t.integer "number_of_test_cases", default: 0
    t.integer "stg_bugs_vn", default: 0
    t.integer "stg_bugs_jp", default: 0
    t.integer "prod_bugs", default: 0
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "issue_link"
    t.index ["assignee_id"], name: "index_tasks_on_assignee_id"
    t.index ["parent_id"], name: "index_tasks_on_parent_id"
    t.index ["project_id"], name: "index_tasks_on_project_id"
    t.index ["status"], name: "index_tasks_on_status"
  end

  create_table "test_cases", force: :cascade do |t|
    t.integer "task_id", null: false
    t.integer "created_by_id"
    t.string "title", null: false
    t.text "description"
    t.text "expected_result"
    t.string "test_type"
    t.string "function"
    t.string "target"
    t.string "acceptance_criteria_url"
    t.string "user_story_url"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_test_cases_on_created_by_id"
    t.index ["deleted_at"], name: "index_test_cases_on_deleted_at"
    t.index ["target"], name: "index_test_cases_on_target"
    t.index ["task_id"], name: "index_test_cases_on_task_id"
    t.index ["test_type"], name: "index_test_cases_on_test_type"
  end

  create_table "test_results", force: :cascade do |t|
    t.integer "run_id"
    t.integer "case_id", null: false
    t.string "status"
    t.text "device"
    t.integer "executed_by_id"
    t.datetime "executed_at"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["case_id"], name: "index_test_results_on_case_id"
    t.index ["deleted_at"], name: "index_test_results_on_deleted_at"
    t.index ["executed_by_id"], name: "index_test_results_on_executed_by_id"
    t.index ["run_id"], name: "index_test_results_on_run_id"
  end

  create_table "test_runs", force: :cascade do |t|
    t.integer "task_id", null: false
    t.integer "executed_by_id"
    t.string "name", null: false
    t.text "description"
    t.datetime "executed_at"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_test_runs_on_deleted_at"
    t.index ["executed_at"], name: "index_test_runs_on_executed_at"
    t.index ["executed_by_id"], name: "index_test_runs_on_executed_by_id"
    t.index ["task_id"], name: "index_test_runs_on_task_id"
  end

  create_table "test_step_contents", force: :cascade do |t|
    t.integer "step_id", null: false
    t.string "content_type", null: false
    t.text "content_value", null: false
    t.boolean "is_expected", default: false, null: false
    t.string "content_category", default: "action", null: false
    t.integer "display_order", default: 0
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["content_category"], name: "index_test_step_contents_on_content_category"
    t.index ["content_type"], name: "index_test_step_contents_on_content_type"
    t.index ["deleted_at"], name: "index_test_step_contents_on_deleted_at"
    t.index ["display_order"], name: "index_test_step_contents_on_display_order"
    t.index ["is_expected"], name: "index_test_step_contents_on_is_expected"
    t.index ["step_id"], name: "index_test_step_contents_on_step_id"
  end

  create_table "test_steps", force: :cascade do |t|
    t.integer "case_id", null: false
    t.integer "step_number", null: false
    t.text "description"
    t.string "function"
    t.integer "display_order", default: 0
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["case_id"], name: "index_test_steps_on_case_id"
    t.index ["deleted_at"], name: "index_test_steps_on_deleted_at"
    t.index ["display_order"], name: "index_test_steps_on_display_order"
    t.index ["step_number"], name: "index_test_steps_on_step_number"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", null: false
    t.string "provider", default: "local", null: false
    t.string "name"
    t.string "avatar"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "role", default: 1, null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "activity_logs", "users"
  add_foreign_key "daily_import_runs", "projects"
  add_foreign_key "notification_reads", "notifications"
  add_foreign_key "notification_reads", "users"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
end
