require "test_helper"

class WarehouseIdempotencyTest < ActiveJob::TestCase
  # Stands in for the warehouse. It models what the MERGE statements promise: a row whose key is
  # already present is not inserted again. Snowflake's own MERGE is checked against a real warehouse
  # separately (see rails/ARCHITECTURE.md section 6.8).
  class FakeWarehouse
    attr_reader :statements, :tables

    def initialize
      @statements = []
      @tables = { transactions: {}, app_events: {} }
    end

    def query(statement, bindings = [])
      @statements << statement
      if statement.include?("MERGE INTO transactions")
        merge(:transactions, bindings, Warehouse::Statements::TRANSACTION_BINDS)
      elsif statement.include?("MERGE INTO app_events")
        merge(:app_events, bindings, Warehouse::Statements::APP_EVENT_BINDS)
      end
      []
    end

    private

    # The first value of each row is its key. The first copy of a key wins, as a NOT MATCHED insert would.
    def merge(table, bindings, width)
      bindings.each_slice(width) { |row| @tables[table][row.first] ||= row }
    end
  end

  setup do
    @user = create_user("u_1001")
    @lantern = create_restaurant("r_101")
    @warehouse = FakeWarehouse.new
    @txn = Txn.create!(transaction_key: "tx_idem", user: @user, restaurant: @lantern,
                       subtotal_cents: 6240, tip_cents: 0, reward_applied: false)
    @view = AppEvent.create!(user: @user, event_name: "restaurant_viewed", restaurant: @lantern,
                             occurred_at: Time.utc(2026, 11, 2, 9, 0, 0))
  end

  def export
    Warehouse::Export.new(client: @warehouse, now: Time.utc(2026, 11, 2, 9, 5)).run
  end

  test "re-sending after a failed marking leaves one row per key" do
    export
    # The statement succeeded but the marking step failed, so the rows look pending again.
    Txn.update_all(exported_at: nil)
    AppEvent.update_all(exported_at: nil)
    export

    assert_equal [ "tx_idem" ], @warehouse.tables[:transactions].keys
    assert_equal [ @view.event_key ], @warehouse.tables[:app_events].keys
  end

  test "every write is a MERGE, never a plain INSERT" do
    export

    assert @warehouse.statements.any? { |sql| sql.include?("MERGE INTO transactions") }
    assert @warehouse.statements.any? { |sql| sql.include?("MERGE INTO app_events") }
    assert @warehouse.statements.none? { |sql| sql.include?("INSERT INTO") }
  end

  test "an app event carries a key built from its name, user, restaurant and time" do
    assert_equal "restaurant_viewed:u_1001:r_101:2026-11-02T09:00:00.000000Z", @view.event_key
  end

  test "a key is set once and is the same when the event is exported again" do
    before = @view.event_key
    export
    Txn.update_all(exported_at: nil)
    AppEvent.update_all(exported_at: nil)
    export

    assert_equal before, @view.reload.event_key
  end
end
