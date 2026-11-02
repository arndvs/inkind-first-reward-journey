class PingJob < ApplicationJob
  queue_as :default

  def perform(message)
    Rails.logger.info("PingJob performed: #{message}")
  end
end
