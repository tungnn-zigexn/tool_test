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

ActiveRecord::Schema[8.0].define(version: 2025_11_11_142252) do
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

  create_table "projects", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "task_histories", force: :cascade do |t|
    t.integer "task_id", null: false
    t.integer "user_id", null: false
    t.string "action", null: false
    t.text "old_value"
    t.text "new_value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action"], name: "index_task_histories_on_action"
    t.index ["task_id"], name: "index_task_histories_on_task_id"
    t.index ["user_id"], name: "index_task_histories_on_user_id"
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
    t.index ["assignee_id"], name: "index_tasks_on_assignee_id"
    t.index ["parent_id"], name: "index_tasks_on_parent_id"
    t.index ["project_id"], name: "index_tasks_on_project_id"
    t.index ["status"], name: "index_tasks_on_status"
  end

  create_table "test_case_histories", force: :cascade do |t|
    t.integer "test_case_id", null: false
    t.integer "user_id", null: false
    t.string "action", null: false
    t.text "old_value"
    t.text "new_value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action"], name: "index_test_case_histories_on_action"
    t.index ["test_case_id"], name: "index_test_case_histories_on_test_case_id"
    t.index ["user_id"], name: "index_test_case_histories_on_user_id"
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

  create_table "test_environments", force: :cascade do |t|
    t.string "name", null: false
    t.string "version"
    t.string "os"
    t.text "description"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_test_environments_on_deleted_at"
    t.index ["name"], name: "index_test_environments_on_name"
  end

  create_table "test_results", force: :cascade do |t|
    t.integer "run_id", null: false
    t.integer "case_id", null: false
    t.string "status", null: false
    t.text "actual_result"
    t.integer "executed_by_id"
    t.datetime "executed_at"
    t.integer "environment_id"
    t.integer "bug_id"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bug_id"], name: "index_test_results_on_bug_id"
    t.index ["case_id"], name: "index_test_results_on_case_id"
    t.index ["deleted_at"], name: "index_test_results_on_deleted_at"
    t.index ["environment_id"], name: "index_test_results_on_environment_id"
    t.index ["executed_by_id"], name: "index_test_results_on_executed_by_id"
    t.index ["run_id"], name: "index_test_results_on_run_id"
    t.index ["status"], name: "index_test_results_on_status"
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
    t.string "password_digest"
    t.string "provider", default: "local", null: false
    t.string "name"
    t.string "avatar"
    t.string "role", default: "tester", null: false
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end
end
