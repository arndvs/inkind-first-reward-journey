module Warehouse
  # Sends new and changed rows to Snowflake (RAILS_DEMO). Each Rails row is marked exported only after the
  # statement that carries it succeeds. A failure raises Snowflake::Error and leaves the rest pending for the
  # next run. See rails/ARCHITECTURE.md section 6.8.
  class Export
    BATCH_SIZE = 100
    TIMESTAMP_FORMAT = "%Y-%m-%d %H:%M:%S.%6N".freeze

    def initialize(client: Snowflake::Client.new, now: Time.current)
      @client = client
      @now = now
    end

    # Returns how many rows each table sent. Returns {} without calling Snowflake when nothing is pending.
    def run
      return {} unless pending?

      {
        transactions: export_transactions,
        app_events: export_app_events,
        rewards: export_rewards
      }
    end

    def pending_counts
      {
        transactions: Txn.where(exported_at: nil).count,
        app_events: AppEvent.where(exported_at: nil).count,
        rewards: pending_rewards.count
      }
    end

    private

    def pending?
      pending_counts.values.any?(&:positive?)
    end

    # A reward is pending when it is new, or when it was redeemed after its last export.
    def pending_rewards
      Reward.where(exported_at: nil).or(Reward.where("redeemed_at > exported_at"))
    end

    def export_transactions
      rows = Txn.where(exported_at: nil).includes(:user).order(:created_at, :id).to_a
      rows.each_slice(BATCH_SIZE) do |batch|
        binds = batch.flat_map do |txn|
          [
            txn.transaction_key,
            txn.user.external_id,
            MoneyFormat.dollars(txn.subtotal_cents).to_s("F"),
            txn.reward_applied.to_s,
            timestamp(txn.created_at)
          ]
        end
        @client.query(Statements.transactions_insert(batch.size), binds)
        Txn.where(id: batch.map(&:id)).update_all(exported_at: @now)
      end
      rows.size
    end

    def export_app_events
      rows = AppEvent.where(exported_at: nil).includes(:user, :restaurant).order(:occurred_at, :id).to_a
      rows.each_slice(BATCH_SIZE) do |batch|
        binds = batch.flat_map do |event|
          [ event.user.external_id, event.event_name, event.restaurant&.key, timestamp(event.occurred_at) ]
        end
        @client.query(Statements.app_events_insert(batch.size), binds)
        AppEvent.where(id: batch.map(&:id)).update_all(exported_at: @now)
      end
      rows.size
    end

    # One MERGE per reward, so each reward is marked exported on its own statement's success.
    def export_rewards
      rows = pending_rewards.includes(:user).order(:id).to_a
      rows.each do |reward|
        @client.query(
          Statements.reward_merge,
          [
            reward.reward_key,
            reward.user.external_id,
            reward.reward_type,
            MoneyFormat.dollars(reward.amount_cents).to_s("F"),
            reward.min_spend_cents && MoneyFormat.dollars(reward.min_spend_cents).to_s("F"),
            reward.redeemed_at && timestamp(reward.redeemed_at)
          ]
        )
        reward.update_columns(exported_at: @now)
      end
      rows.size
    end

    def timestamp(time)
      time.utc.strftime(TIMESTAMP_FORMAT)
    end
  end
end
