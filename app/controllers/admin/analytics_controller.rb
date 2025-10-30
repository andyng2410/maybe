module Admin
  class AnalyticsController < ApplicationController
    before_action :require_super_admin

    def index
      @time_range = params[:range] || "30"
      start_date = @time_range.to_i.days.ago
      end_date = Time.current

      @metrics = SubscriptionEvent.metrics_summary(start_date: start_date, end_date: end_date)

      @trial_timeline = SubscriptionEvent
        .where(event_type: [ "trial_started", "trial_converted", "trial_expired" ])
        .in_date_range(start_date, end_date)
        .group("DATE(occurred_at)")
        .group(:event_type)
        .count
        .transform_keys { |k| { date: k[0], event_type: k[1] } }

      @recent_events = SubscriptionEvent
        .includes(:family, :subscription)
        .recent
        .limit(50)
    end

    private

    def require_super_admin
      unless Current.user&.super_admin?
        redirect_to root_path, alert: "Access denied"
      end
    end
  end
end
