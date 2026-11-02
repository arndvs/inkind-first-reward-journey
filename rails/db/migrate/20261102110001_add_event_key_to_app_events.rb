class AddEventKeyToAppEvents < ActiveRecord::Migration[8.1]
  # The key Snowflake MERGEs on, so a re-sent export can't duplicate an event. Same format as AppEvent.event_key_for.
  def up
    add_column :app_events, :event_key, :string

    # Rows that already exist get their key now, so a later export can't duplicate them either.
    select_all(<<~SQL).each do |row|
      SELECT app_events.id, app_events.event_name, app_events.occurred_at,
             users.external_id, restaurants.key AS restaurant_key
      FROM app_events
      JOIN users ON users.id = app_events.user_id
      LEFT JOIN restaurants ON restaurants.id = app_events.restaurant_id
    SQL
      key = [
        row["event_name"],
        row["external_id"],
        row["restaurant_key"].presence || "-",
        Time.zone.parse(row["occurred_at"].to_s).utc.iso8601(6)
      ].join(":")
      execute("UPDATE app_events SET event_key = #{connection.quote(key)} WHERE id = #{row['id'].to_i}")
    end

    add_index :app_events, :event_key, unique: true
  end

  def down
    remove_index :app_events, :event_key
    remove_column :app_events, :event_key
  end
end
