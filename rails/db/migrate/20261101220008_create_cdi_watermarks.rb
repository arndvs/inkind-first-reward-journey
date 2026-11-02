class CreateCdiWatermarks < ActiveRecord::Migration[8.1]
  def change
    create_table :cdi_watermarks do |t|
      t.string :view_name, null: false
      t.datetime :synced_through
    end

    add_index :cdi_watermarks, :view_name, unique: true
  end
end
