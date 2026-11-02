class CreateBrazeDeliveries < ActiveRecord::Migration[8.1]
  def change
    create_table :braze_deliveries do |t|
      t.string :idempotency_key, null: false
      t.references :user, null: false, foreign_key: true
      t.string :endpoint, null: false
      t.json :payload, null: false
      t.string :status, null: false, default: "pending"
      t.integer :attempts, null: false, default: 0
      t.text :last_error
      t.datetime :recorded_at
      t.timestamps
    end

    add_index :braze_deliveries, :idempotency_key, unique: true
  end
end
