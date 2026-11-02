module Warehouse
  # SQL text for the export. Every value is a ? placeholder bound as TEXT and cast in the SQL.
  # Each write is a MERGE on a key, so sending the same row twice leaves one row. See rails/ARCHITECTURE.md section 6.8.
  module Statements
    TRANSACTION_BINDS = 5 # transaction_id, user_id, amount, reward_applied, created_at
    APP_EVENT_BINDS = 5   # event_key, user_id, event_name, restaurant_id, event_at

    # Load time in UTC. CURRENT_TIMESTAMP() follows the session time zone, so it is converted explicitly.
    LOADED_AT = "CONVERT_TIMEZONE('UTC', CURRENT_TIMESTAMP())::TIMESTAMP_NTZ".freeze

    TRANSACTION_COLUMNS = [
      [ "transaction_id", "?" ],
      [ "user_id", "?" ],
      [ "amount", "?::NUMBER(10,2)" ],
      [ "reward_applied", "?::BOOLEAN" ],
      [ "created_at", "?::TIMESTAMP_NTZ" ]
    ].freeze

    APP_EVENT_COLUMNS = [
      [ "event_key", "?" ],
      [ "user_id", "?" ],
      [ "event_name", "?" ],
      [ "restaurant_id", "?" ],
      [ "event_at", "?::TIMESTAMP_NTZ" ]
    ].freeze

    REWARD_MERGE = <<~SQL.freeze
      MERGE INTO rewards t
      USING (
        SELECT ? AS reward_id, ? AS user_id, ? AS reward_type, ?::NUMBER(10,2) AS amount,
               ?::NUMBER(10,2) AS min_spend, ?::TIMESTAMP_NTZ AS redeemed_at
      ) s
      ON t.reward_id = s.reward_id
      WHEN MATCHED THEN UPDATE SET t.redeemed_at = s.redeemed_at, t.updated_at = #{LOADED_AT}
      WHEN NOT MATCHED THEN INSERT (reward_id, user_id, reward_type, amount, min_spend, redeemed_at, updated_at)
        VALUES (s.reward_id, s.user_id, s.reward_type, s.amount, s.min_spend, s.redeemed_at, #{LOADED_AT})
    SQL

    module_function

    # Inserts a transaction only if its transaction_id is not already in the warehouse.
    def transactions_merge(row_count)
      <<~SQL
        MERGE INTO transactions t
        USING (#{source_rows(TRANSACTION_COLUMNS, row_count)}) s
        ON t.transaction_id = s.transaction_id
        WHEN NOT MATCHED THEN INSERT (transaction_id, user_id, amount, reward_applied, created_at, loaded_at)
          VALUES (s.transaction_id, s.user_id, s.amount, s.reward_applied, s.created_at, #{LOADED_AT})
      SQL
    end

    # Inserts an event only if its event_key is not already in the warehouse.
    def app_events_merge(row_count)
      <<~SQL
        MERGE INTO app_events t
        USING (#{source_rows(APP_EVENT_COLUMNS, row_count)}) s
        ON t.event_key = s.event_key
        WHEN NOT MATCHED THEN INSERT (event_key, user_id, event_name, restaurant_id, event_at)
          VALUES (s.event_key, s.user_id, s.event_name, s.restaurant_id, s.event_at)
      SQL
    end

    def reward_merge
      REWARD_MERGE
    end

    # One SELECT per row, joined with UNION ALL. The first row names the columns; the rest only list values.
    def source_rows(columns, row_count)
      Array.new(row_count) do |index|
        expressions = columns.map do |name, expression|
          index.zero? ? "#{expression} AS #{name}" : expression
        end
        "SELECT #{expressions.join(', ')}"
      end.join(" UNION ALL ")
    end
  end
end
