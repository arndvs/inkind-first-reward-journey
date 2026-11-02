class CreateRewards < ActiveRecord::Migration[8.1]
  def change
    create_table :rewards do |t|
      t.string :reward_key, null: false
      t.references :user, null: false, foreign_key: true
      t.string :reward_type, null: false
      t.integer :amount_cents, null: false
      t.integer :min_spend_cents
      t.datetime :redeemed_at
      t.datetime :exported_at
      t.timestamps
    end

    add_index :rewards, :reward_key, unique: true
    add_index :rewards, :user_id,
              unique: true,
              where: "reward_type = 'referral_welcome'",
              name: "index_rewards_one_referral_welcome_per_user"
  end
end
