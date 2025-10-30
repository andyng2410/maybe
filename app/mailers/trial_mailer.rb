class TrialMailer < ApplicationMailer
  def expiring_soon
    @family = params[:family]
    @days_remaining = params[:days_remaining]
    @user = @family.users.admins.first || @family.users.first

    mail(to: @family.billing_email, subject: "Your Maybe trial expires in #{@days_remaining} days")
  end

  def expired
    @family = params[:family]
    @user = @family.users.admins.first || @family.users.first

    mail(to: @family.billing_email, subject: "Your Maybe trial has expired")
  end

  def payment_failed
    @family = params[:family]
    @subscription = params[:subscription]
    @user = @family.users.admins.first || @family.users.first

    mail(to: @family.billing_email, subject: "Payment failed for your Maybe subscription")
  end
end
