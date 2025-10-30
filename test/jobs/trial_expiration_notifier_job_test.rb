require "test_helper"

class TrialExpirationNotifierJobTest < ActiveJob::TestCase
  setup do
    @family = families(:empty)
    # Ensure family has a trialing subscription
    @subscription = Subscription.create!(
      family: @family,
      status: "trialing",
      trial_ends_at: 3.days.from_now
    )
  end

  test "sends expiration email for trials expiring in 3 days" do
    # Set trial to expire in 3 days
    @subscription.update!(trial_ends_at: 3.days.from_now.beginning_of_day)

    assert_enqueued_emails 1 do
      TrialExpirationNotifierJob.perform_now
    end
  end

  test "sends expiration email for trials expiring in 1 day" do
    # Set trial to expire in 1 day
    @subscription.update!(trial_ends_at: 1.day.from_now.beginning_of_day)

    assert_enqueued_emails 1 do
      TrialExpirationNotifierJob.perform_now
    end
  end

  test "marks expired trials as paused" do
    # Set trial to expired (yesterday)
    @subscription.update!(trial_ends_at: 1.day.ago, status: "trialing")

    TrialExpirationNotifierJob.perform_now

    @subscription.reload
    assert_equal "paused", @subscription.status
  end

  test "does not process in self-hosted mode" do
    # Stub Rails config
    Rails.application.config.stub(:app_mode, "self_hosted".inquiry) do
      assert_no_enqueued_emails do
        TrialExpirationNotifierJob.perform_now
      end
    end
  end
end
