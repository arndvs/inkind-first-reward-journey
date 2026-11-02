module Demo
  # Resets the warehouse side of the demo: re-runs the RAILS_DEMO schema, clears the CDI watermark, and returns
  # a one-line summary. The local database is reset by the rake task, which calls this after it.
  # Development only. See rails/README.md.
  class Reset
    class NotDevelopment < StandardError; end

    REWARD_SQL = "SELECT amount, redeemed_at FROM rewards WHERE reward_id = 'rw_01'".freeze

    def initialize(client: Snowflake::Client.new)
      @client = client
    end

    def run
      raise NotDevelopment, "demo:reset only runs in development" unless Rails.env.development?

      Warehouse::DemoSchema.reset!(client: @client)
      CdiWatermark.where(view_name: Warehouse::CdiPreview::VIEW).delete_all
      summary
    end

    private

    def summary
      pending = Warehouse::Export.new(client: nil).pending_counts.values.sum
      "users=#{User.count} pending_exports=#{pending} rails_demo_u1001_reward=#{reward_state}"
    end

    def reward_state
      row = @client.query(REWARD_SQL).first
      return "not found" if row.nil?
      return "redeemed #{row['REDEEMED_AT']}" if row["REDEEMED_AT"]

      cents = (BigDecimal(row["AMOUNT"].to_s) * 100).to_i
      "unused ($#{MoneyFormat.display(cents)})"
    end
  end
end
