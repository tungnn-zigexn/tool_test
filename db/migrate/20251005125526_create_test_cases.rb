class CreateTestCases < ActiveRecord::Migration[8.0]
  def change
    create_table :test_cases do |t|
      t.integer :task_id, null: false
      t.integer :created_by_id, null: false
      t.string :title, null: false
      t.text :description
      t.text :expected_result

      # Các trường mới cho spreadsheet import
      t.string :test_type, default: "feature" # feature, ui
      t.string :function
      t.string :target, default: "pc_sp_app" # pc, sp, app, pc_sp, pc_sp_app
      t.string :acceptance_criteria_url
      t.string :user_story_url

      t.datetime :deleted_at

      t.timestamps
    end

    add_index :test_cases, :task_id
    add_index :test_cases, :created_by_id
    add_index :test_cases, :deleted_at
    add_index :test_cases, :test_type
    add_index :test_cases, :target
  end
end
