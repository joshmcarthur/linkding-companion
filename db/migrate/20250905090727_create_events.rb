class CreateEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :events do |t|
      t.integer :bookmark_id
      t.string :action, null: false
      t.datetime :occurred_at
      t.text :extra

      t.timestamps
    end
  end
end
