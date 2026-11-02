module Warehouse
  # The rows Braze's Cloud Data Ingestion would pick up on its next sync. This only previews the view's
  # query. Braze runs the real sync. See rails/ARCHITECTURE.md section 6.9.
  class CdiPreview
    VIEW = "braze_first_reward_attributes".freeze
    EPOCH = Time.utc(1970, 1, 1).freeze
    SELECT = "SELECT EXTERNAL_ID, UPDATED_AT, PAYLOAD FROM braze_first_reward_attributes " \
             "WHERE UPDATED_AT > ?::TIMESTAMP_NTZ ORDER BY UPDATED_AT".freeze
    TIMESTAMP_FORMAT = "%Y-%m-%d %H:%M:%S.%6N".freeze

    def initialize(client: Snowflake::Client.new)
      @client = client
    end

    def watermark
      CdiWatermark.find_by(view_name: VIEW)&.synced_through || EPOCH
    end

    # Rows changed after the watermark, oldest first.
    def rows
      @client.query(SELECT, [ watermark.utc.strftime(TIMESTAMP_FORMAT) ]).map do |row|
        { external_id: row["EXTERNAL_ID"], updated_at: parse_time(row["UPDATED_AT"]), payload: parse_payload(row["PAYLOAD"]) }
      end
    end

    def mark_synced!(through)
      record = CdiWatermark.find_or_initialize_by(view_name: VIEW)
      record.update!(synced_through: through.utc)
    end

    private

    # Snowflake returns TIMESTAMP_NTZ as epoch seconds with nanoseconds, for example "1793596440.000000000".
    def parse_time(value)
      text = value.to_s
      return Time.at(Rational(text)).utc if text.match?(/\A\d+(\.\d+)?\z/)

      Time.zone.parse(text).utc
    end

    # Snowflake returns VARIANT as a JSON string.
    def parse_payload(value)
      value.is_a?(String) ? JSON.parse(value) : value
    end
  end
end
