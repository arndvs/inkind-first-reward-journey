require "test_helper"

class WarehouseTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @user = create_user("u_1001")
    @lantern = create_restaurant("r_101")
  end

  test "the warehouse page shows how many rows are waiting to be exported" do
    Txn.create!(transaction_key: "tx_waiting", user: @user, restaurant: @lantern,
                subtotal_cents: 6240, tip_cents: 0, reward_applied: false)

    get warehouse_path

    assert_response :success
    assert_includes response.body, "Transactions waiting"
    assert_includes response.body, "1"
  end

  test "run export now enqueues the export job" do
    assert_enqueued_with(job: Warehouse::ExportJob) do
      post warehouse_export_path
    end

    assert_redirected_to warehouse_path
  end
end
