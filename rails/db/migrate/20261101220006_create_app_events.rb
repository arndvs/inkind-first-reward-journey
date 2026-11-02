class CreateAppEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :app_events do |t|
      t.references :user, null: false, foreign_key: true
      t.string :event_name, null: false
      t.references :restaurant, foreign_key: true
      t.datetime :occurred_at, null: false
      t.datetime :exported_at
    end

    add_index :app_events, :exported_at
  end
end
