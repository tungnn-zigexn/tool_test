class CreateTestEnvironments < ActiveRecord::Migration[8.0]
  def change
    create_table :test_environments do |t|
      t.string :name, null: false
      t.string :version
      t.string :os
      t.text :description
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :test_environments, :name
    add_index :test_environments, :deleted_at
  end
end
