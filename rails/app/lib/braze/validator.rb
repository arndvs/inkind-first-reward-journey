module Braze
  # Checks a /users/track body against the rules in rails/ARCHITECTURE.md section 6.3.
  # Raises Braze::InvalidPayload listing every problem found, or returns true.
  class Validator
    MAX_OBJECTS_PER_ARRAY = 75
    REQUIRED_FIELDS = {
      "attributes" => %w[ external_id ],
      "events" => %w[ external_id name time ],
      "purchases" => %w[ external_id product_id currency price time ]
    }.freeze

    def self.check!(payload)
      problems = []

      REQUIRED_FIELDS.each do |array_name, required|
        objects = Array(payload[array_name])

        if objects.size > MAX_OBJECTS_PER_ARRAY
          problems << "#{array_name} has #{objects.size} objects; the limit is #{MAX_OBJECTS_PER_ARRAY}"
        end

        objects.each_with_index do |object, index|
          required.each do |field|
            problems << "#{array_name}[#{index}] is missing #{field}" if object[field].blank?
          end
          if object["time"].present? && !iso8601?(object["time"])
            problems << "#{array_name}[#{index}] has a time that is not ISO 8601: #{object['time']}"
          end
        end
      end

      raise Braze::InvalidPayload, problems.join("; ") if problems.any?

      true
    end

    def self.iso8601?(value)
      Time.iso8601(value.to_s)
      true
    rescue ArgumentError
      false
    end
    private_class_method :iso8601?
  end
end
