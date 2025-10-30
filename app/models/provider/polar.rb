class Provider::Polar
  Error = Class.new(StandardError)

  # Polar.sh API integration
  # Documentation: https://docs.polar.sh
  # Based on search results, Polar uses REST API with similar patterns to Stripe

  def initialize(api_key:, webhook_secret:)
    @api_key = api_key
    @webhook_secret = webhook_secret
    @base_url = "https://api.polar.sh"
  end

  def create_checkout_session(plan:, family_id:, family_email:, success_url:, cancel_url:)
    # Polar.sh checkout session creation
    # Endpoint: POST /v1/checkouts/custom
    response = make_request(
      :post,
      "/v1/checkouts/custom",
      {
        product_price_id: price_id_for(plan),
        customer_email: family_email,
        success_url: success_url,
        customer_metadata: {
          family_id: family_id
        }
      }
    )

    NewCheckoutSession.new(url: response["url"], checkout_id: response["id"])
  rescue StandardError => e
    Rails.logger.error "Error creating Polar checkout session: #{e.message}"
    raise Error, "Failed to create checkout session: #{e.message}"
  end

  def get_checkout_result(checkout_id)
    # Verify checkout completion
    # Endpoint: GET /v1/checkouts/{id}
    response = make_request(:get, "/v1/checkouts/#{checkout_id}")

    if response["status"] == "confirmed"
      CheckoutSessionResult.new(success?: true, subscription_id: response["subscription_id"])
    else
      CheckoutSessionResult.new(success?: false, subscription_id: nil)
    end
  rescue StandardError => e
    Sentry.capture_exception(e) if defined?(Sentry)
    Rails.logger.error "Error fetching Polar checkout result: #{e.message}"
    CheckoutSessionResult.new(success?: false, subscription_id: nil)
  end

  def create_customer_portal_url(customer_id:, return_url:)
    # Polar customer portal for managing subscriptions
    # Note: This endpoint may differ - verify with Polar docs
    response = make_request(
      :post,
      "/v1/customers/portal",
      {
        customer_id: customer_id,
        return_url: return_url
      }
    )

    response["url"]
  rescue StandardError => e
    Rails.logger.error "Error creating Polar customer portal: #{e.message}"
    raise Error, "Failed to create customer portal: #{e.message}"
  end

  def process_webhook(webhook_body, signature)
    # Verify webhook signature
    verify_webhook_signature!(webhook_body, signature)

    event = JSON.parse(webhook_body)
    PolarEventHandlerJob.perform_later(event)
  end

  def process_event(event)
    # Process different event types
    case event["type"]
    when "checkout.created"
      handle_checkout_created(event)
    when "subscription.created", "subscription.updated"
      handle_subscription_event(event)
    when "subscription.canceled"
      handle_subscription_canceled(event)
    when "order.created"
      handle_order_created(event)
    else
      Rails.logger.warn "Unhandled Polar event type: #{event['type']}"
    end
  end

  private

  attr_reader :api_key, :webhook_secret, :base_url

  NewCheckoutSession = Data.define(:url, :checkout_id)
  CheckoutSessionResult = Data.define(:success?, :subscription_id)

  def make_request(method, path, body = nil)
    require "net/http"
    require "json"

    uri = URI("#{base_url}#{path}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = case method
    when :get
      Net::HTTP::Get.new(uri)
    when :post
      Net::HTTP::Post.new(uri)
    when :put
      Net::HTTP::Put.new(uri)
    when :delete
      Net::HTTP::Delete.new(uri)
    end

    request["Authorization"] = "Bearer #{api_key}"
    request["Content-Type"] = "application/json"
    request.body = body.to_json if body

    response = http.request(request)

    unless response.is_a?(Net::HTTPSuccess)
      raise Error, "Polar API error: #{response.code} #{response.body}"
    end

    JSON.parse(response.body)
  end

  def verify_webhook_signature!(payload, signature)
    # Verify webhook signature using HMAC
    expected_signature = OpenSSL::HMAC.hexdigest(
      "SHA256",
      webhook_secret,
      payload
    )

    unless Rack::Utils.secure_compare(signature, expected_signature)
      raise Error, "Invalid webhook signature"
    end
  end

  def price_id_for(plan)
    # Map plan types to Polar price IDs
    prices = {
      monthly: ENV["POLAR_MONTHLY_PRICE_ID"],
      annual: ENV["POLAR_ANNUAL_PRICE_ID"]
    }

    prices[plan.to_sym] || prices[:monthly]
  end

  def handle_checkout_created(event)
    # Track checkout creation
    Rails.logger.info("Polar checkout created: #{event['data']['id']}")
  end

  def handle_subscription_event(event)
    subscription_data = event["data"]
    customer_metadata = subscription_data.dig("customer", "metadata") || {}
    family_id = customer_metadata["family_id"]

    return unless family_id

    family = Family.find_by(id: family_id)
    return unless family

    # Update or create subscription
    subscription = family.subscription || family.build_subscription
    subscription.update!(
      status: map_polar_status(subscription_data["status"]),
      interval: subscription_data["recurring_interval"],
      amount: subscription_data["amount"] / 100.0,
      currency: subscription_data["currency"],
      current_period_ends_at: Time.parse(subscription_data["current_period_end"])
    )

    # Track event
    SubscriptionEvent.create!(
      family: family,
      subscription: subscription,
      event_type: event["type"] == "subscription.created" ? "subscription_created" : "subscription_updated",
      event_data: subscription_data,
      occurred_at: Time.current
    )
  end

  def handle_subscription_canceled(event)
    subscription_data = event["data"]
    customer_metadata = subscription_data.dig("customer", "metadata") || {}
    family_id = customer_metadata["family_id"]

    return unless family_id

    family = Family.find_by(id: family_id)
    return unless family&.subscription

    family.subscription.update!(status: "canceled")

    SubscriptionEvent.create!(
      family: family,
      subscription: family.subscription,
      event_type: "subscription_canceled",
      event_data: subscription_data,
      occurred_at: Time.current
    )
  end

  def handle_order_created(event)
    # Handle one-time payment orders
    Rails.logger.info("Polar order created: #{event['data']['id']}")
  end

  def map_polar_status(polar_status)
    # Map Polar subscription statuses to our internal statuses
    case polar_status
    when "active"
      "active"
    when "canceled", "cancelled"
      "canceled"
    when "incomplete"
      "incomplete"
    when "past_due"
      "past_due"
    else
      polar_status
    end
  end
end
