class MakeTransactionsRestaurantOptional < ActiveRecord::Migration[8.1]
  # sql/00 transactions have no restaurant. Imported history keeps that; app payments must name one (see Txn).
  def change
    change_column_null :transactions, :restaurant_id, true
  end
end
