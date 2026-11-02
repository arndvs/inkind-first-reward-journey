class WarehouseController < ApplicationController
  def show
    @pending = Warehouse::Export.new(client: nil).pending_counts
  end

  # Runs the export in the background job, the same as the schedule does.
  def export
    Warehouse::ExportJob.perform_later
    redirect_to warehouse_path, notice: "Export queued. Rows appear in Snowflake once the job runs."
  end

  def cdi_preview
    preview = Warehouse::CdiPreview.new
    @watermark = preview.watermark
    @rows = preview.rows
    @newest = @rows.map { |row| row[:updated_at] }.max
  end

  # Stores the newest time the page showed. Braze's real sync is what actually advances.
  def mark_synced
    through = Time.iso8601(params.expect(:synced_through))
    Warehouse::CdiPreview.new.mark_synced!(through)
    redirect_to warehouse_cdi_preview_path, notice: "Marked synced through #{through.utc.iso8601}."
  rescue ArgumentError
    redirect_to warehouse_cdi_preview_path, alert: "That isn't a time, so nothing was marked."
  end
end
