class TrialExpirationNotifierJob < ApplicationJob
  queue_as :scheduled

  def perform
    return unless Rails.application.config.app_mode.managed?

    notify_trials_expiring_in_days(3)
    notify_trials_expiring_in_days(1)
    mark_expired_trials
  end

  private

  def notify_trials_expiring_in_days(days)
    target_date = days.days.from_now.beginning_of_day

    # Find trials expiring on the target date that haven't been notified yet
    expiring_subscriptions = Subscription.trialing.where(
      trial_ends_at: target_date..target_date.end_of_day
    )

    expiring_subscriptions.find_each do |subscription|
      family = subscription.family
      next unless family&.billing_email.present?

      # Send email notification
      TrialMailer.with(family: family, days_remaining: days).expiring_soon.deliver_later

      # Track the notification event
      SubscriptionEvent.create!(
        subscription: subscription,
        family: family,
        event_type: "trial_expiration_reminder_sent",
        event_data: { days_remaining: days }
      ) if defined?(SubscriptionEvent)

      Rails.logger.info("Sent trial expiration reminder to family #{family.id} (#{days} days remaining)")
    end
  end

  def mark_expired_trials
    # Find trials that expired yesterday or earlier but haven't been marked as expired
    expired_subscriptions = Subscription.trialing.where("trial_ends_at < ?", Time.current.beginning_of_day)

    expired_subscriptions.find_each do |subscription|
      family = subscription.family
      next unless family

      # Sync trial status (marks as paused)
      family.sync_trial_status!

      # Send expiration email
      TrialMailer.with(family: family).expired.deliver_later if family.billing_email.present?

      # Track the expiration event
      SubscriptionEvent.create!(
        subscription: subscription,
        family: family,
        event_type: "trial_expired",
        event_data: { expired_at: Time.current }
      ) if defined?(SubscriptionEvent)

      Rails.logger.info("Marked trial as expired for family #{family.id}")
    end
  end
end
