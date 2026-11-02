class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :external_id, null: false
      t.string :email, null: false
      t.timestamps
    end

    add_index :users, :external_id, unique: true
  end
end
