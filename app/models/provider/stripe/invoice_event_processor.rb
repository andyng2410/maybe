class Provider::Stripe::InvoiceEventProcessor < Provider::Stripe::EventProcessor
  Error = Class.new(StandardError)

  def process
    raise Error, "Family not found for Stripe customer ID: #{invoice.customer}" unless family

    case event.type
    when "invoice.payment_failed"
      handle_payment_failed
    when "invoice.payment_succeeded"
      handle_payment_succeeded
    else
      Rails.logger.warn "Unhandled invoice event type: #{event.type}"
    end
  end

  private

  def handle_payment_failed
    # Track the payment failure event
    SubscriptionEvent.create!(
      family: family,
      subscription: family.subscription,
      event_type: "payment_failed",
      event_data: {
        invoice_id: invoice.id,
        amount_due: invoice.amount_due / 100.0,
        currency: invoice.currency,
        attempt_count: invoice.attempt_count,
        next_payment_attempt: invoice.next_payment_attempt ? Time.at(invoice.next_payment_attempt) : nil
      },
      occurred_at: Time.current
    )

    # Send notification email
    TrialMailer.with(
      family: family,
      subscription: family.subscription
    ).payment_failed.deliver_later

    # Schedule retry if this is not the final attempt
    if invoice.attempt_count < 3
      PaymentRetryJob.set(wait: retry_delay(invoice.attempt_count)).perform_later(invoice.id, family.id)
    end

    Rails.logger.info("Payment failed for family #{family.id}, attempt #{invoice.attempt_count}")
  end

  def handle_payment_succeeded
    # Track successful payment
    SubscriptionEvent.create!(
      family: family,
      subscription: family.subscription,
      event_type: "payment_succeeded",
      event_data: {
        invoice_id: invoice.id,
        amount_paid: invoice.amount_paid / 100.0,
        currency: invoice.currency
      },
      occurred_at: Time.current
    )

    Rails.logger.info("Payment succeeded for family #{family.id}")
  end

  def retry_delay(attempt_count)
    # Exponential backoff: 1 day, 3 days, 7 days
    case attempt_count
    when 1
      1.day
    when 2
      3.days
    else
      7.days
    end
  end

  def family
    @family ||= Family.find_by(stripe_customer_id: invoice.customer)
  end

  def invoice
    event_data
  end
end
