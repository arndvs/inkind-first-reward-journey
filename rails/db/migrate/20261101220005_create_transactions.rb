class CreateTransactions < ActiveRecord::Migration[8.1]
  def change
    create_table :transactions do |t|
      t.string :transaction_key, null: false
      t.references :user, null: false, foreign_key: true
      t.references :restaurant, null: false, foreign_key: true
      t.integer :subtotal_cents, null: false
      t.integer :tip_cents, null: false, default: 0
      t.boolean :reward_applied, null: false, default: false
      t.datetime :exported_at
      t.timestamps
    end

    add_index :transactions, :transaction_key, unique: true
  end
end
