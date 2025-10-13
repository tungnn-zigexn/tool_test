class CreateTasks < ActiveRecord::Migration[8.0]
  def change
    create_table :tasks do |t|
      t.integer :project_id, null: false
      t.integer :assignee_id
      t.integer :parent_id

      t.string :title, null: false
      t.text :description
      t.string :status, default: "in_progress"

      t.decimal :estimated_time, precision: 5, scale: 2
      t.decimal :spent_time, precision: 5, scale: 2
      t.integer :percent_done
      t.date :start_date
      t.date :due_date

      # Các trường mới cho spreadsheet import
      t.string :testcase_link
      t.string :bug_link
      t.string :description_link
      t.string :created_by_name
      t.string :reviewed_by_name
      t.integer :number_of_test_cases, default: 0

      t.datetime :deleted_at

      t.timestamps
    end

    add_index :tasks, :project_id
    add_index :tasks, :assignee_id
    add_index :tasks, :parent_id
    add_index :tasks, :status
  end
end
