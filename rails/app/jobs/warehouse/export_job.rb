module Warehouse
  # Runs the export on the recurring schedule (config/recurring.yml) or on demand from the warehouse page.
  # A failed run leaves its rows pending; the next run sends them.
  class ExportJob < ApplicationJob
    queue_as :warehouse

    def perform
      Warehouse::Export.new.run
    end
  end
end
