module Braze
  # Braze returned 429 or 5xx, or the request never completed. The job retries with the stored payload.
  class RetryableError < StandardError; end
end
