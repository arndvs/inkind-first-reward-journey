module Braze
  # Raised by Braze::Validator when a /users/track body breaks the Braze rules in
  # rails/ARCHITECTURE.md section 6.3. Its own file, so Zeitwerk can autoload it.
  class InvalidPayload < StandardError; end
end
