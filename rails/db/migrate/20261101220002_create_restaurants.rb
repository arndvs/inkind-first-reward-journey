class CreateRestaurants < ActiveRecord::Migration[8.1]
  def change
    create_table :restaurants do |t|
      t.string :key, null: false
      t.string :name, null: false
      t.string :location_id, null: false
      t.string :cuisine
      t.string :price
      t.decimal :rating, precision: 2, scale: 1
      t.integer :cashback_pct
      t.string :image_url
      t.string :thumb_url
      t.text :description
      t.timestamps
    end

    add_index :restaurants, :key, unique: true
  end
end
