require "test_helper"

class SubscriptionEventTest < ActiveSupport::TestCase
  test "creates event with required attributes" do
    family = families(:dylan_family)
    subscription = subscriptions(:active)

    event = SubscriptionEvent.create!(
      family: family,
      subscription: subscription,
      event_type: "trial_started",
      event_data: { status: "trialing" },
      occurred_at: Time.current
    )

    assert event.persisted?
    assert_equal "trial_started", event.event_type
    assert_equal family, event.family
  end

  test "validates event_type inclusion" do
    family = families(:dylan_family)

    event = SubscriptionEvent.new(
      family: family,
      event_type: "invalid_type",
      occurred_at: Time.current
    )

    assert_not event.valid?
    assert_includes event.errors[:event_type], "is not included in the list"
  end

  test "calculates trial conversion rate" do
    family1 = families(:dylan_family)
    family2 = families(:empty)

    # Create trial started events
    SubscriptionEvent.create!(
      family: family1,
      event_type: "trial_started",
      occurred_at: 10.days.ago
    )

    SubscriptionEvent.create!(
      family: family2,
      event_type: "trial_started",
      occurred_at: 10.days.ago
    )

    # Create one conversion
    SubscriptionEvent.create!(
      family: family1,
      event_type: "trial_converted",
      occurred_at: 5.days.ago
    )

    conversion_rate = SubscriptionEvent.trial_conversion_rate(start_date: 30.days.ago)

    assert_equal 50.0, conversion_rate
  end

  test "metrics_summary returns correct data" do
    family = families(:dylan_family)

    SubscriptionEvent.create!(
      family: family,
      event_type: "trial_started",
      occurred_at: 5.days.ago
    )

    SubscriptionEvent.create!(
      family: family,
      event_type: "trial_converted",
      occurred_at: 2.days.ago
    )

    metrics = SubscriptionEvent.metrics_summary(start_date: 7.days.ago)

    assert_equal 1, metrics[:trials_started]
    assert_equal 1, metrics[:trials_converted]
    assert_equal 100.0, metrics[:conversion_rate]
  end
end
