require "test_helper"

class QueueSmokeTest < ActiveJob::TestCase
  class PingJob < ApplicationJob
    queue_as :default

    class_attribute :ran, default: false

    def perform(value)
      self.class.ran = value
    end
  end

  test "an enqueued job runs when performed" do
    assert_enqueued_jobs 1, only: PingJob do
      PingJob.perform_later("pong")
    end

    perform_enqueued_jobs only: PingJob
    assert_equal "pong", PingJob.ran
  end
end
