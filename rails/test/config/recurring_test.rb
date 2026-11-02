require "test_helper"

class RecurringConfigTest < ActiveSupport::TestCase
  test "the warehouse export runs every 10 minutes in development" do
    config = YAML.load_file(Rails.root.join("config", "recurring.yml"), aliases: true)

    entry = config.dig("development", "warehouse_export")

    assert_equal "Warehouse::ExportJob", entry["class"]
    assert_equal "every 10 minutes", entry["schedule"]
  end
end
