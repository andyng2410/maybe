require "test_helper"

class TrialMailerTest < ActionMailer::TestCase
  setup do
    @family = families(:empty)
    @user = users(:family_admin)
    @subscription = Subscription.create!(
      family: @family,
      status: "trialing",
      trial_ends_at: 3.days.from_now
    )
  end

  test "expiring_soon email" do
    email = TrialMailer.with(
      family: @family,
      days_remaining: 3
    ).expiring_soon

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal [@family.billing_email], email.to
    assert_equal "Your Maybe trial expires in 3 days", email.subject
    assert_match "3 days", email.body.encoded
  end

  test "expired email" do
    email = TrialMailer.with(family: @family).expired

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal [@family.billing_email], email.to
    assert_equal "Your Maybe trial has expired", email.subject
    assert_match "trial has expired", email.body.encoded
  end

  test "payment_failed email" do
    email = TrialMailer.with(
      family: @family,
      subscription: @subscription
    ).payment_failed

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal [@family.billing_email], email.to
    assert_equal "Payment failed for your Maybe subscription", email.subject
    assert_match "unable to process your payment", email.body.encoded
  end
end
