module Braze
  # Sends one /users/track body for one record. The payload is built once, when its delivery row is
  # created. Retries resend that stored payload and never rebuild it from changed data.
  # See rails/ARCHITECTURE.md section 6.5.
  class TrackJob < ApplicationJob
    queue_as :braze

    retry_on Braze::RetryableError, wait: :polynomially_longer, attempts: 5
    discard_on Braze::PermanentError, Braze::InvalidPayload

    def perform(kind, record_gid)
      record = GlobalID::Locator.locate(record_gid)
      # find_or_create_by! looks first. create_or_find_by! would hit the uniqueness validation on a repeat run.
      delivery = BrazeDelivery.find_or_create_by!(idempotency_key: idempotency_key(kind, record)) do |row|
        row.user = record.user
        row.endpoint = "/users/track"
        row.payload = Braze::Payloads.public_send(kind, record)
      end
      return if delivery.recorded?

      delivery.increment!(:attempts)
      result = Braze::Client.new.track(delivery.payload)
      delivery.update!(status: "recorded", recorded_at: Time.current, last_error: result["errors"]&.to_json)
    rescue Braze::RetryableError => error
      delivery&.update!(last_error: error.message)
      raise
    rescue Braze::PermanentError, Braze::InvalidPayload => error
      delivery&.update!(status: "failed", last_error: error.message)
      raise
    end

    private

    def idempotency_key(kind, record)
      identifier = kind == "purchase" ? record.transaction_key : record.id
      "#{kind}:#{identifier}"
    end
  end
end
