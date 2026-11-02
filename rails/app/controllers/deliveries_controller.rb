class DeliveriesController < ApplicationController
  def index
    @deliveries = BrazeDelivery.includes(:user).order(created_at: :desc)
  end

  # Queues the same job again for the same record. Braze::TrackJob finds the existing delivery by its key, so
  # re-sending never creates a second row, and a delivery already recorded is not sent again.
  def resend
    delivery = BrazeDelivery.find(params[:id])
    kind, record_gid = delivery.job_arguments
    Braze::TrackJob.perform_later(kind, record_gid)
    redirect_to deliveries_path, notice: "Re-send queued for #{delivery.idempotency_key}."
  rescue ActiveRecord::RecordNotFound, ArgumentError
    redirect_to deliveries_path,
                alert: "The record for this delivery could not be found, so nothing was re-sent."
  end
end
