class Subscription < ApplicationRecord
  TRIAL_DAYS = 14

  belongs_to :family
  has_many :subscription_events, dependent: :destroy

  # https://docs.stripe.com/api/subscriptions/object
  enum :status, {
    incomplete: "incomplete",
    incomplete_expired: "incomplete_expired",
    trialing: "trialing", # We use this, but "offline" (no through Stripe's interface)
    active: "active",
    past_due: "past_due",
    canceled: "canceled",
    unpaid: "unpaid",
    paused: "paused"
  }

  validates :stripe_id, presence: true, if: :active?
  validates :trial_ends_at, presence: true, if: :trialing?
  validates :family_id, uniqueness: true

  after_create :track_creation_event
  after_update :track_status_change_event

  class << self
    def new_trial_ends_at
      TRIAL_DAYS.days.from_now
    end
  end

  def name
    case interval
    when "month"
      "Monthly Plan"
    when "year"
      "Annual Plan"
    else
      "Free trial"
    end
  end

  private

  def track_creation_event
    event_type = if trialing?
      "trial_started"
    elsif active?
      "subscription_created"
    else
      return
    end

    SubscriptionEvent.create!(
      family: family,
      subscription: self,
      event_type: event_type,
      event_data: {
        status: status,
        interval: interval,
        amount: amount,
        currency: currency
      },
      occurred_at: Time.current
    )
  rescue => e
    Rails.logger.error("Failed to track subscription creation event: #{e.message}")
  end

  def track_status_change_event
    return unless saved_change_to_status?

    previous_status = status_before_last_save
    current_status = status

    event_type = case [ previous_status, current_status ]
    when [ "trialing", "active" ]
      "trial_converted"
    when [ "trialing", "paused" ], [ "trialing", "canceled" ]
      "trial_expired"
    when [ "active", "canceled" ]
      "subscription_canceled"
    else
      "subscription_updated"
    end

    SubscriptionEvent.create!(
      family: family,
      subscription: self,
      event_type: event_type,
      event_data: {
        previous_status: previous_status,
        current_status: current_status,
        interval: interval,
        amount: amount,
        currency: currency
      },
      occurred_at: Time.current
    )
  rescue => e
    Rails.logger.error("Failed to track subscription status change event: #{e.message}")
  end
end
