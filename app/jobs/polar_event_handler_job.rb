class PolarEventHandlerJob < ApplicationJob
  queue_as :default

  def perform(event)
    polar = Provider::Registry.polar
    return unless polar

    polar.process_event(event)
  rescue => e
    Rails.logger.error("Failed to process Polar event: #{e.message}")
    Sentry.capture_exception(e) if defined?(Sentry)
    raise
  end
end
