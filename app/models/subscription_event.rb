class SubscriptionEvent < ApplicationRecord
  belongs_to :family
  belongs_to :subscription, optional: true

  # Event types
  EVENT_TYPES = %w[
    trial_started
    trial_expiration_reminder_sent
    trial_expired
    trial_converted
    subscription_created
    subscription_updated
    subscription_canceled
    payment_succeeded
    payment_failed
    payment_retry_attempted
  ].freeze

  validates :event_type, presence: true, inclusion: { in: EVENT_TYPES }
  validates :occurred_at, presence: true

  scope :recent, -> { order(occurred_at: :desc) }
  scope :by_type, ->(type) { where(event_type: type) }
  scope :for_family, ->(family_id) { where(family_id: family_id) }
  scope :in_date_range, ->(start_date, end_date) { where(occurred_at: start_date..end_date) }

  # Analytics helpers
  def self.trial_conversion_rate(start_date: 90.days.ago, end_date: Time.current)
    trials_started = where(event_type: "trial_started")
                      .in_date_range(start_date, end_date)
                      .distinct
                      .count(:family_id)

    trials_converted = where(event_type: "trial_converted")
                        .in_date_range(start_date, end_date)
                        .distinct
                        .count(:family_id)

    return 0 if trials_started.zero?
    (trials_converted.to_f / trials_started * 100).round(2)
  end

  def self.payment_failure_rate(start_date: 30.days.ago, end_date: Time.current)
    payment_attempts = where(event_type: "payment_succeeded")
                        .or(where(event_type: "payment_failed"))
                        .in_date_range(start_date, end_date)
                        .count

    payment_failures = where(event_type: "payment_failed")
                        .in_date_range(start_date, end_date)
                        .count

    return 0 if payment_attempts.zero?
    (payment_failures.to_f / payment_attempts * 100).round(2)
  end

  def self.metrics_summary(start_date: 30.days.ago, end_date: Time.current)
    {
      trials_started: where(event_type: "trial_started").in_date_range(start_date, end_date).count,
      trials_converted: where(event_type: "trial_converted").in_date_range(start_date, end_date).count,
      trials_expired: where(event_type: "trial_expired").in_date_range(start_date, end_date).count,
      conversion_rate: trial_conversion_rate(start_date: start_date, end_date: end_date),
      subscriptions_created: where(event_type: "subscription_created").in_date_range(start_date, end_date).count,
      subscriptions_canceled: where(event_type: "subscription_canceled").in_date_range(start_date, end_date).count,
      payment_failures: where(event_type: "payment_failed").in_date_range(start_date, end_date).count,
      payment_failure_rate: payment_failure_rate(start_date: start_date, end_date: end_date)
    }
  end
end
