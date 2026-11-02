require "test_helper"

class PingJobTest < ActiveJob::TestCase
  test "enqueues on the default queue and performs" do
    assert_enqueued_with(job: PingJob, args: [ "pong" ], queue: "default") do
      PingJob.perform_later("pong")
    end

    assert_nothing_raised do
      perform_enqueued_jobs
    end
  end
end
