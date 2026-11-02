module Snowflake
  # Snowflake rejected a statement, or it did not finish in time. `code` is Snowflake's error code when it sent one.
  class Error < StandardError
    attr_reader :code

    def initialize(message, code: nil)
      super(message)
      @code = code
    end
  end
end
