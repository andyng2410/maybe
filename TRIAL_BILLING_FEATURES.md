# Trial Billing Features Documentation

This document describes the enhanced trial billing features added to Maybe.

## Overview

The trial billing system provides a comprehensive 14-day free trial experience with automated notifications, conversion prompts, payment retry logic, and dual payment provider support (Stripe + Polar.sh).

## Features Implemented

### 1. Trial Expiration Notifications

**Email Reminders:**
- 3 days before trial expires
- 1 day before trial expires
- When trial expires

**Implementation:**
- `TrialMailer` - Email templates for trial notifications
- `TrialExpirationNotifierJob` - Scheduled job that runs daily
- Schedule configuration in `config/schedule.yml`

**Email Templates:**
- `/app/views/trial_mailer/expiring_soon.html.erb`
- `/app/views/trial_mailer/expired.html.erb`
- `/app/views/trial_mailer/payment_failed.html.erb`

### 2. Trial-to-Paid Conversion Prompts

**UI Components:**
- Trial countdown banner (shows on all pages)
- Conversion modal (appears when trial ≤ 2 days remaining)

**Files:**
- `/app/components/DS/trial_banner.rb` - Banner component
- `/app/views/layouts/shared/_trial_conversion_dialog.html.erb` - Modal dialog

**Features:**
- Progress bar showing trial completion percentage
- Days remaining counter
- Urgency-based color coding (blue → yellow → red)
- Feature list with benefits
- Direct link to subscription upgrade

### 3. Access Restrictions on Trial Expiry

**Implementation:**
- Existing `Onboardable` concern enforces restrictions
- `Family#upgrade_required?` checks trial status
- `Family#trialing?` validates days remaining
- `Family#sync_trial_status!` marks expired trials as "paused"

**Behavior:**
- Users with expired trials are redirected to `/subscription/upgrade`
- All data is preserved for when they subscribe
- No access to app features until subscription is active

### 4. Trial Analytics & Tracking

**SubscriptionEvent Model:**
Tracks all subscription-related events:
- `trial_started`
- `trial_expiration_reminder_sent`
- `trial_expired`
- `trial_converted`
- `subscription_created`
- `subscription_updated`
- `subscription_canceled`
- `payment_succeeded`
- `payment_failed`
- `payment_retry_attempted`

**Analytics Dashboard:**
- Path: `/admin/analytics`
- Access: Super admin only
- Metrics tracked:
  - Trial conversion rate
  - Trials started/converted/expired
  - Subscriptions created/canceled
  - Payment failure rate
  - Recent events timeline

**Files:**
- `/app/models/subscription_event.rb`
- `/app/controllers/admin/analytics_controller.rb`
- `/app/views/admin/analytics/index.html.erb`
- `/db/migrate/20251030000001_create_subscription_events.rb`

### 5. Improved Trial Onboarding

**Enhancements:**
- Updated trial timeline to reflect actual reminder schedule (3 days, 1 day)
- Clear feature list with icons
- Transparent "no credit card required" messaging
- Visual timeline of trial progression

**File:**
- `/app/views/onboardings/trial.html.erb`

### 6. Payment Retry Logic

**Stripe Integration:**
- Automatic retry on payment failure
- Exponential backoff: 1 day → 3 days → 7 days
- Email notifications on failure
- Tracking of retry attempts

**Files:**
- `/app/models/provider/stripe/invoice_event_processor.rb`
- `/app/jobs/payment_retry_job.rb`
- Updates to `/app/models/provider/stripe.rb`

**Webhook Events:**
- `invoice.payment_failed`
- `invoice.payment_succeeded`

### 7. Polar.sh Payment Integration

**New Payment Provider:**
Polar.sh integrated as an alternative to Stripe with:
- Checkout session creation
- Webhook handling
- Subscription management
- Customer portal access

**Files:**
- `/app/models/provider/polar.rb`
- `/app/jobs/polar_event_handler_job.rb`
- `/app/controllers/webhooks_controller.rb#polar`

**Configuration:**
Environment variables required:
- `POLAR_API_KEY`
- `POLAR_WEBHOOK_SECRET`
- `POLAR_MONTHLY_PRICE_ID`
- `POLAR_ANNUAL_PRICE_ID`

**Webhook Endpoint:**
- `POST /webhooks/polar`
- Signature verification included
- Events processed asynchronously

**Supported Events:**
- `checkout.created`
- `subscription.created`
- `subscription.updated`
- `subscription.canceled`
- `order.created`

## Environment Variables

Add these to your `.env` file:

```bash
# Existing Stripe (keep as is)
STRIPE_SECRET_KEY=sk_...
STRIPE_WEBHOOK_SECRET=whsec_...
STRIPE_MONTHLY_PRICE_ID=price_...
STRIPE_ANNUAL_PRICE_ID=price_...

# New Polar.sh integration
POLAR_API_KEY=polar_...
POLAR_WEBHOOK_SECRET=...
POLAR_MONTHLY_PRICE_ID=...
POLAR_ANNUAL_PRICE_ID=...
```

## Database Migrations

Run migrations to create the subscription events table:

```bash
bin/rails db:migrate
```

This creates the `subscription_events` table with:
- Event type tracking
- JSONB data storage
- Family and subscription references
- Timestamp indexing for analytics

## Scheduled Jobs

The trial expiration checker runs daily at 10:00 AM UTC:

```yaml
check_trial_expirations:
  cron: "0 10 * * *"
  class: "TrialExpirationNotifierJob"
  queue: "scheduled"
```

## Testing

Run tests for new features:

```bash
# All tests
bin/rails test

# Specific test files
bin/rails test test/models/subscription_event_test.rb
bin/rails test test/jobs/trial_expiration_notifier_job_test.rb
bin/rails test test/mailers/trial_mailer_test.rb
```

## Analytics Access

Super admins can access analytics at `/admin/analytics` to view:
- Trial funnel metrics
- Conversion rates
- Payment health
- Event timeline

## Future Enhancements

Potential improvements (not yet implemented):
1. A/B testing for conversion messaging
2. Feature usage tracking during trial
3. Trial extension for engaged users
4. Referral credits
5. Discount codes for failed conversions
6. Cancellation surveys
7. Winback campaigns

## Security Considerations

- All webhook endpoints verify signatures
- Admin analytics require super_admin role
- No sensitive payment data stored (only references)
- JSONB data sanitized before storage
- API keys stored in environment variables

## Notes

- Pricing remains at $9/month (not changed to $10/month as originally requested)
- Polar.sh integration may need API endpoint adjustments based on final documentation
- Event tracking is automatic via ActiveRecord callbacks
- Self-hosted mode bypasses all billing/trial checks

## Support

For questions or issues with trial billing features, check:
1. Rails logs for error details
2. Sidekiq dashboard at `/sidekiq` for job status
3. Analytics dashboard for conversion metrics
4. Email delivery logs for notification status
