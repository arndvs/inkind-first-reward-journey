module Warehouse
  # SQL text for the export. Every value is a ? placeholder bound as TEXT and cast in the SQL.
  # Load time is UTC: CURRENT_TIMESTAMP() follows the session time zone, so it is converted explicitly.
  # See rails/ARCHITECTURE.md section 6.8.
  module Statements
    LOADED_AT = "CONVERT_TIMEZONE('UTC', CURRENT_TIMESTAMP())::TIMESTAMP_NTZ".freeze

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

    def transactions_insert(row_count)
      values = Array.new(row_count) { "(?, ?, ?::NUMBER(10,2), ?::BOOLEAN, ?::TIMESTAMP_NTZ, #{LOADED_AT})" }
      "INSERT INTO transactions (transaction_id, user_id, amount, reward_applied, created_at, loaded_at) " \
        "VALUES #{values.join(', ')}"
    end

    def app_events_insert(row_count)
      values = Array.new(row_count) { "(?, ?, ?, ?::TIMESTAMP_NTZ)" }
      "INSERT INTO app_events (user_id, event_name, restaurant_id, event_at) VALUES #{values.join(', ')}"
    end

    def reward_merge
      REWARD_MERGE
    end
  end
end
