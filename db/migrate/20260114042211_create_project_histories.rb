class CreateProjectHistories < ActiveRecord::Migration[8.0]
  def change
    create_table :project_histories do |t|
      t.integer :project_id, null: false
      t.integer :user_id, null: false
      t.string :action, null: false
      t.text :old_value
      t.text :new_value

      t.timestamps
    end

    add_index :project_histories, :project_id
    add_index :project_histories, :user_id
    add_index :project_histories, :action
  end
end
