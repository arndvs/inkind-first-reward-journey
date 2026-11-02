class CreateSavedRestaurants < ActiveRecord::Migration[8.1]
  def change
    create_table :saved_restaurants do |t|
      t.references :user, null: false, foreign_key: true
      t.references :restaurant, null: false, foreign_key: true
      t.timestamps
    end

    add_index :saved_restaurants, [ :user_id, :restaurant_id ], unique: true
  end
end
