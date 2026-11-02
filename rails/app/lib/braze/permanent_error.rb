module Braze
  # Braze rejected the request with a 4xx other than 429. Retrying the same payload won't help.
  class PermanentError < StandardError; end
end
