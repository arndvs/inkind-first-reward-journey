module Braze
  # Sends one /users/track body for one record. The payload is built once, when its delivery row is
  # created. Retries resend that stored payload and never rebuild it from changed data.
  # See rails/ARCHITECTURE.md section 6.5.
  class TrackJob < ApplicationJob
    queue_as :braze

    retry_on Braze::RetryableError, wait: :polynomially_longer, attempts: 5 do |job, error|
      job.mark_failed!(error, "retries exhausted: #{error.message}")
    end
    discard_on Braze::PermanentError, Braze::InvalidPayload

    def perform(kind, record_gid)
      record = locate(record_gid)
      return if record.nil? # removed before its job ran; see #locate
      delivery = find_or_create_delivery(kind, record)
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

    # A record removed after it was queued can no longer be located. Its removal writes its own event, which
    # carries the current list, so nothing is left to send for the removed record.
    def locate(record_gid)
      GlobalID::Locator.locate(record_gid)
    rescue ActiveRecord::RecordNotFound
      nil
    end

    # Called by retry_on once the attempts run out. Keeps the delivery visible as failed.
    def mark_failed!(_error, message)
      kind, record_gid = arguments
      record = GlobalID::Locator.locate(record_gid)
      BrazeDelivery.find_by!(idempotency_key: idempotency_key(kind, record))
                   .update!(status: "failed", last_error: message)
    end

    private

    # Looks first. If a concurrent run creates the row between the look-up and the insert, the unique
    # index raises RecordNotUnique and we reuse the row the other run made.
    def find_or_create_delivery(kind, record)
      key = idempotency_key(kind, record)
      BrazeDelivery.find_by(idempotency_key: key) || create_delivery(kind, record, key)
    end

    def create_delivery(kind, record, key)
      delivery = BrazeDelivery.new(
        idempotency_key: key,
        user: record.user,
        endpoint: "/users/track",
        payload: Braze::Payloads.public_send(kind, record)
      )
      # The uniqueness check already ran in find_by. The unique index is the guard against a race.
      delivery.save!(validate: false)
      delivery
    rescue ActiveRecord::RecordNotUnique
      BrazeDelivery.find_by!(idempotency_key: key)
    end

    def idempotency_key(kind, record)
      identifier = kind == "purchase" ? record.transaction_key : record.id
      "#{kind}:#{identifier}"
    end
  end
end
