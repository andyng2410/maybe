class PaymentRetryJob < ApplicationJob
  queue_as :default

  def perform(invoice_id, family_id)
    family = Family.find_by(id: family_id)
    return unless family&.stripe_customer_id

    # Attempt to retry the payment via Stripe
    stripe = Provider::Registry.new.stripe
    invoice = stripe.client.v1.invoices.retrieve(invoice_id)

    # Only retry if invoice is still open/unpaid
    return unless invoice.status == "open"

    # Stripe will automatically retry, but we can force a retry here if needed
    stripe.client.v1.invoices.pay(invoice_id)

    # Track the retry attempt
    SubscriptionEvent.create!(
      family: family,
      subscription: family.subscription,
      event_type: "payment_retry_attempted",
      event_data: {
        invoice_id: invoice_id,
        retry_count: invoice.attempt_count
      },
      occurred_at: Time.current
    )

    Rails.logger.info("Payment retry attempted for family #{family_id}, invoice #{invoice_id}")
  rescue Stripe::CardError, Stripe::InvalidRequestError => e
    # Payment failed again, log and let Stripe webhooks handle it
    Rails.logger.error("Payment retry failed for family #{family_id}: #{e.message}")
  rescue => e
    Rails.logger.error("Error in payment retry job: #{e.message}")
    Sentry.capture_exception(e) if defined?(Sentry)
  end
end
