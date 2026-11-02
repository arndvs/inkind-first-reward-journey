class WarehouseController < ApplicationController
  def show
    @pending = Warehouse::Export.new(client: nil).pending_counts
  end

  # Runs the export in the background job, the same as the schedule does.
  def export
    Warehouse::ExportJob.perform_later
    redirect_to warehouse_path, notice: "Export queued. Rows appear in Snowflake once the job runs."
  end
end
