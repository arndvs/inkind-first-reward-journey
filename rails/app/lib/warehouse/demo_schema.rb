module Warehouse
  # Runs sql/10_rails_demo_schema.sql through the SQL API, one statement per request. The SQL API takes one
  # statement at a time, so the file is split on semicolons after its -- comments are removed.
  module DemoSchema
    PATH = Rails.root.join("..", "sql", "10_rails_demo_schema.sql")

    module_function

    # USE is dropped: the SQL API rejects it, and the request already names the database and schema.
    def statements(text = File.read(PATH))
      text.gsub(/--[^\n]*/, "")
          .split(";")
          .map(&:strip)
          .reject { |statement| statement.empty? || statement.start_with?("USE ") }
    end

    def reset!(client:)
      statements.each { |statement| client.query(statement) }
    end
  end
end
